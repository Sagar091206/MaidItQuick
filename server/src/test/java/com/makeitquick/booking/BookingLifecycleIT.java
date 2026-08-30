package com.makeitquick.booking;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.makeitquick.notification.NotificationService;
import com.makeitquick.notification.NotificationType;
import com.makeitquick.operations.AvailabilityStatus;
import com.makeitquick.security.JwtService;
import com.makeitquick.security.Role;
import com.makeitquick.security.UserAccount;
import com.makeitquick.security.UserRepository;
import com.makeitquick.worker.WorkerProfile;
import com.makeitquick.worker.WorkerProfileRepository;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/**
 * End-to-end booking lifecycle tests against an in-memory H2 database.
 *
 * <p>Verifies the customer booking journey: creation as unpaid and unassigned,
 * payment before assignment, worker acceptance, on-the-way, OTP-gated start and
 * completion, rating, and the cancellation and validation rules.</p>
 */
@SpringBootTest(properties = {
        "spring.datasource.url=jdbc:h2:mem:bookingflow;MODE=MySQL;DB_CLOSE_DELAY=-1",
        "spring.datasource.driver-class-name=org.h2.Driver",
        "spring.datasource.username=sa",
        "spring.datasource.password=",
        "spring.jpa.hibernate.ddl-auto=create-drop",
        "app.admin.email=",
        "app.admin.password=",
        "app.sms.enabled=false",
        "app.uploads.directory=target/test-kyc-uploads"
})
@AutoConfigureMockMvc
class BookingLifecycleIT {

    private static final String PIN = "712235";
    private static final Pattern OTP_PATTERN = Pattern.compile("(\\d{6})$");

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private BookingEventRepository bookingEvents;

    @Autowired
    private NotificationService notificationService;

    @Autowired
    private ScheduledBookingDispatchService scheduledDispatch;

    @Autowired
    private UserRepository users;

    @Autowired
    private WorkerProfileRepository profiles;

    @Autowired
    private JwtService jwt;

    @PersistenceContext
    private EntityManager em;

    @Autowired
    private org.springframework.transaction.PlatformTransactionManager txManager;

    /**
     * Clears rows created by previous tests (dependency order) so the
     * auto-dispatch engine only sees this test's eligible worker. The seeded
     * service catalog and default service area (712235) are intentionally kept.
     */
    @BeforeEach
    void cleanDatabase() {
        new org.springframework.transaction.support.TransactionTemplate(txManager).executeWithoutResult(status -> {
            em.createQuery("delete from Payment").executeUpdate();
            em.createQuery("delete from BookingEvent").executeUpdate();
            em.createQuery("delete from BookingService").executeUpdate();
            em.createQuery("delete from Booking").executeUpdate();
            em.createQuery("delete from AppNotification").executeUpdate();
            em.createQuery("delete from Session").executeUpdate();
            em.createQuery("delete from PartnerOtp").executeUpdate();
            em.createQuery("delete from PendingRegistration").executeUpdate();
            em.createQuery("delete from RevokedToken").executeUpdate();
            em.createQuery("delete from WorkerProfile").executeUpdate();
            em.createQuery("delete from UserAccount").executeUpdate();
            em.clear();
        });
    }

    @Test
    void bookingIsUnpaidAndUnassignedUntilPayment() throws Exception {
        UserAccount customer = newCustomer("+919800000001", true);
        UserAccount worker = newEligibleWorker("+919800000002");

        JsonNode created = createBooking(customer, worker, futureTime());
        assertThat(created.get("status").asText()).isEqualTo("REQUESTED");
        assertThat(created.get("paymentStatus").asText()).isEqualTo("UNPAID");
        assertThat(created.get("worker").asText()).isEqualTo("Unassigned");
        assertThat(created.get("paymentAmountPaise").asInt()).isGreaterThan(0);

        // Payment first, then automatic assignment fires.
        payFor(customer, created.get("id").asLong(), "UPI");

        JsonNode paid = expect(mockMvc.perform(get("/api/bookings/" + created.get("id").asLong())
                .header("Authorization", "Bearer " + jwt.issue(customer))), 200);
        assertThat(paid.get("paymentStatus").asText()).isEqualTo("PAID");
        assertThat(paid.get("status").asText()).isEqualTo("ASSIGNED");
        assertThat(paid.get("worker").asText()).isEqualTo(worker.getName());
    }

    @Test
    void scheduledBookingFallsBackToAvailableOffShiftWorker() throws Exception {
        UserAccount customer = newCustomer("+919800000019", true);
        UserAccount worker = newEligibleWorker("+919800000020");
        LocalDateTime serviceTime = LocalDateTime.now().plusDays(2).withHour(10).withMinute(0).withSecond(0).withNano(0);
        WorkerProfile profile = profiles.findByUser_Id(worker.getId()).orElseThrow();
        profile.setWorkingHours(serviceTime.getDayOfWeek().plus(1).name().toLowerCase(), "09:00", "18:00");
        profiles.save(profile);

        JsonNode created = createBooking(customer, worker, serviceTime.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME));
        payFor(customer, created.get("id").asLong(), "UPI");

        JsonNode paid = expect(mockMvc.perform(get("/api/bookings/" + created.get("id").asLong())
                .header("Authorization", "Bearer " + jwt.issue(customer))), 200);
        assertThat(paid.get("status").asText()).isEqualTo("ASSIGNED");
        assertThat(paid.get("worker").asText()).isEqualTo(worker.getName());
    }

    @Test
    void paidScheduledBookingIsRetriedWhenPartnerBecomesAvailable() throws Exception {
        UserAccount customer = newCustomer("+919800000022", true);
        JsonNode created = createBooking(customer, null, futureTime());
        long id = created.get("id").asLong();
        payFor(customer, id, "UPI");
        assertThat(expect(mockMvc.perform(get("/api/bookings/" + id)
                .header("Authorization", "Bearer " + jwt.issue(customer))), 200)
                .get("status").asText()).isEqualTo("REQUESTED");

        UserAccount worker = newEligibleWorker("+919800000023");
        scheduledDispatch.retryUnassignedPaidBookings();

        JsonNode assigned = expect(mockMvc.perform(get("/api/bookings/" + id)
                .header("Authorization", "Bearer " + jwt.issue(customer))), 200);
        assertThat(assigned.get("status").asText()).isEqualTo("ASSIGNED");
        assertThat(assigned.get("worker").asText()).isEqualTo(worker.getName());
    }

    @Test
    void goingOnlineImmediatelyReceivesStillUnassignedPaidRequest() throws Exception {
        UserAccount customer = newCustomer("+919800000033", true);
        UserAccount worker = newEligibleWorker("+919800000034");
        WorkerProfile profile = profiles.findByUser_Id(worker.getId()).orElseThrow();
        profile.setAvailability(AvailabilityStatus.OFFLINE);
        profiles.save(profile);

        JsonNode created = createBooking(customer, null, futureTime());
        long id = created.get("id").asLong();
        payFor(customer, id, "UPI");
        assertThat(expect(mockMvc.perform(get("/api/bookings/" + id)
                .header("Authorization", "Bearer " + jwt.issue(customer))), 200)
                .get("status").asText()).isEqualTo("REQUESTED");

        postWith(worker, "/api/workers/me/availability", Map.of("status", "AVAILABLE"));

        JsonNode assigned = expect(mockMvc.perform(get("/api/bookings/" + id)
                .header("Authorization", "Bearer " + jwt.issue(customer))), 200);
        assertThat(assigned.get("status").asText()).isEqualTo("ASSIGNED");
        assertThat(assigned.get("worker").asText()).isEqualTo(worker.getName());
    }

    @Test
    void goingOfflineReleasesAndHidesPendingScheduledRequest() throws Exception {
        UserAccount customer = newCustomer("+919800000024", true);
        UserAccount worker = newEligibleWorker("+919800000025");
        JsonNode created = createBooking(customer, worker, futureTime());
        long id = created.get("id").asLong();
        payFor(customer, id, "UPI");

        JsonNode availability = postWith(
                worker, "/api/workers/me/availability", Map.of("status", "OFFLINE"));
        assertThat(availability.get("availability").asText()).isEqualTo("OFFLINE");

        JsonNode customerView = expect(mockMvc.perform(get("/api/bookings/" + id)
                .header("Authorization", "Bearer " + jwt.issue(customer))), 200);
        assertThat(customerView.get("status").asText()).isEqualTo("REQUESTED");
        assertThat(customerView.get("worker").asText()).isEqualTo("Unassigned");

        JsonNode workerBookings = expect(mockMvc.perform(get("/api/bookings")
                .header("Authorization", "Bearer " + jwt.issue(worker))), 200);
        assertThat(workerBookings).noneSatisfy(item ->
                assertThat(item.get("id").asLong()).isEqualTo(id));
        expect(mockMvc.perform(get("/api/bookings/" + id)
                .header("Authorization", "Bearer " + jwt.issue(worker))), 403);

        JsonNode alerts = expect(mockMvc.perform(get("/api/notifications")
                .header("Authorization", "Bearer " + jwt.issue(worker))), 200);
        assertThat(alerts).noneSatisfy(alert ->
                assertThat(alert.path("bookingId").asLong()).isEqualTo(id));
    }

    @Test
    void goingOfflineReassignsRequestToAnotherAvailablePartner() throws Exception {
        UserAccount customer = newCustomer("+919800000030", true);
        UserAccount firstWorker = newEligibleWorker("+919800000031");
        UserAccount secondWorker = newEligibleWorker("+919800000032");
        secondWorker.setName("Second Test Worker");
        users.save(secondWorker);
        JsonNode created = createBooking(customer, firstWorker, futureTime());
        long id = created.get("id").asLong();
        payFor(customer, id, "UPI");

        JsonNode initiallyAssigned = expect(mockMvc.perform(get("/api/bookings/" + id)
                .header("Authorization", "Bearer " + jwt.issue(customer))), 200);
        assertThat(initiallyAssigned.get("worker").asText()).isEqualTo(firstWorker.getName());

        postWith(firstWorker, "/api/workers/me/availability", Map.of("status", "OFFLINE"));

        JsonNode reassigned = expect(mockMvc.perform(get("/api/bookings/" + id)
                .header("Authorization", "Bearer " + jwt.issue(customer))), 200);
        assertThat(reassigned.get("status").asText()).isEqualTo("ASSIGNED");
        assertThat(reassigned.get("worker").asText()).isEqualTo(secondWorker.getName());

        JsonNode firstWorkerBookings = expect(mockMvc.perform(get("/api/bookings")
                .header("Authorization", "Bearer " + jwt.issue(firstWorker))), 200);
        assertThat(firstWorkerBookings).noneSatisfy(item ->
                assertThat(item.get("id").asLong()).isEqualTo(id));

        JsonNode secondWorkerBookings = expect(mockMvc.perform(get("/api/bookings")
                .header("Authorization", "Bearer " + jwt.issue(secondWorker))), 200);
        assertThat(secondWorkerBookings).anySatisfy(item -> {
            assertThat(item.get("id").asLong()).isEqualTo(id);
            assertThat(item.get("status").asText()).isEqualTo("ASSIGNED");
        });
    }

    @Test
    void offlinePartnerCannotAcceptStaleAssignedRequest() throws Exception {
        UserAccount customer = newCustomer("+919800000026", true);
        UserAccount worker = newEligibleWorker("+919800000027");
        JsonNode created = createBooking(customer, worker, futureTime());
        long id = created.get("id").asLong();
        payFor(customer, id, "UPI");

        WorkerProfile profile = profiles.findByUser_Id(worker.getId()).orElseThrow();
        profile.setAvailability(AvailabilityStatus.OFFLINE);
        profiles.save(profile);

        JsonNode error = expect(post("/api/bookings/" + id + "/accept")
                .header("Authorization", "Bearer " + jwt.issue(worker)), 409);
        assertThat(error.get("message").asText()).contains("Go online");

        JsonNode workerBookings = expect(mockMvc.perform(get("/api/bookings")
                .header("Authorization", "Bearer " + jwt.issue(worker))), 200);
        assertThat(workerBookings).noneSatisfy(item ->
                assertThat(item.get("id").asLong()).isEqualTo(id));
    }

    @Test
    void customerCannotReadAnotherCustomersUnassignedBooking() throws Exception {
        UserAccount owner = newCustomer("+919800000028", true);
        UserAccount other = newCustomer("+919800000029", true);
        JsonNode created = createBooking(owner, null, futureTime());

        expect(mockMvc.perform(get("/api/bookings/" + created.get("id").asLong())
                .header("Authorization", "Bearer " + jwt.issue(other))), 403);
    }

    @Test
    void customerCanCancelBeforeWorkerTravelsIncludingAccepted() throws Exception {
        UserAccount customer = newCustomer("+919800000003", true);
        UserAccount worker = newEligibleWorker("+919800000004");

        JsonNode created = createBooking(customer, worker, futureTime());
        long id = created.get("id").asLong();
        payFor(customer, id, "UPI");

        // Worker accepts, but has not yet travelled.
        postWith(worker, "/api/bookings/" + id + "/accept");

        JsonNode cancelled = postWith(customer, "/api/bookings/" + id + "/cancel", Map.of("reason", "Changed my mind"));
        assertThat(cancelled.get("status").asText()).isEqualTo("CANCELLED");
    }

    @Test
    void fullJobLifecycleWithOtpGatesCompletes() throws Exception {
        UserAccount customer = newCustomer("+919800000005", true);
        UserAccount worker = newEligibleWorker("+919800000006");

        JsonNode created = createBooking(customer, worker, futureTime());
        long id = created.get("id").asLong();
        payFor(customer, id, "UPI");

        postWith(worker, "/api/bookings/" + id + "/accept");
        postWith(worker, "/api/bookings/" + id + "/on-the-way");

        postWith(worker, "/api/bookings/" + id + "/start-code");
        String startOtp = latestOtpFor(customer);
        JsonNode started = postWith(worker, "/api/bookings/" + id + "/start", Map.of("code", startOtp));
        assertThat(started.get("status").asText()).isEqualTo("IN_PROGRESS");

        postWith(worker, "/api/bookings/" + id + "/end-code");
        String endOtp = latestOtpFor(customer);
        JsonNode completed = postWith(worker, "/api/bookings/" + id + "/complete", Map.of("code", endOtp));
        assertThat(completed.get("status").asText()).isEqualTo("COMPLETED");

        JsonNode rated = postWith(customer, "/api/bookings/" + id + "/rating",
                Map.of("stars", 5, "comment", "Great service"));
        assertThat(rated.get("status").asText()).isEqualTo("COMPLETED");
    }

    @Test
    void acceptedJobSurvivesFreshPartnerSessionAndRepeatedAccept() throws Exception {
        UserAccount customer = newCustomer("+919800000017", true);
        UserAccount worker = newEligibleWorker("+919800000018");
        JsonNode created = createBooking(customer, worker, futureTime());
        long id = created.get("id").asLong();
        payFor(customer, id, "UPI");

        String firstToken = jwt.issue(worker);
        JsonNode accepted = expect(post("/api/bookings/" + id + "/accept")
                .header("Authorization", "Bearer " + firstToken), 200);
        assertThat(accepted.get("status").asText()).isEqualTo("ACCEPTED");

        expect(post("/api/auth/logout")
                .header("Authorization", "Bearer " + firstToken), 200);
        String freshToken = jwt.issue(worker);
        JsonNode restored = expect(get("/api/bookings")
                .header("Authorization", "Bearer " + freshToken), 200);
        assertThat(restored).anySatisfy(item -> {
            assertThat(item.get("id").asLong()).isEqualTo(id);
            assertThat(item.get("status").asText()).isEqualTo("ACCEPTED");
        });

        JsonNode repeated = expect(post("/api/bookings/" + id + "/accept")
                .header("Authorization", "Bearer " + freshToken), 200);
        assertThat(repeated.get("status").asText()).isEqualTo("ACCEPTED");
        assertThat(bookingEvents.findByBookingIdOrderByCreatedAtAsc(id).stream()
                .filter(event -> event.getStatus() == BookingStatus.ACCEPTED)).hasSize(1);

        JsonNode alerts = expect(get("/api/notifications")
                .header("Authorization", "Bearer " + freshToken), 200);
        assertThat(alerts).anySatisfy(alert -> {
            assertThat(alert.get("title").asText()).isEqualTo("New booking request");
            assertThat(alert.get("bookingId").asLong()).isEqualTo(id);
            assertThat(alert.get("read").asBoolean()).isTrue();
        });
        assertThat(alerts).anySatisfy(alert -> {
            assertThat(alert.get("title").asText()).isEqualTo("Job accepted");
            assertThat(alert.get("bookingId").asLong()).isEqualTo(id);
            assertThat(alert.get("read").asBoolean()).isFalse();
        });
    }

    @Test
    void notificationInboxLoadsHistoricalPaymentAlerts() throws Exception {
        UserAccount customer = newCustomer("+919800000021", true);
        notificationService.send(customer, NotificationType.BOOKING,
                "Booking update", "Your booking was updated.");
        notificationService.send(customer, NotificationType.PAYMENT,
                "Refund issued", "Your payment was refunded.");

        JsonNode alerts = expect(get("/api/notifications")
                .header("Authorization", "Bearer " + jwt.issue(customer)), 200);
        assertThat(alerts).extracting(item -> item.get("type").asText())
                .contains("BOOKING", "PAYMENT");
    }

    @Test
    void workerCannotRequestStartOtpBeforeTravelling() throws Exception {
        UserAccount customer = newCustomer("+919800000007", true);
        UserAccount worker = newEligibleWorker("+919800000008");

        JsonNode created = createBooking(customer, worker, futureTime());
        long id = created.get("id").asLong();
        payFor(customer, id, "UPI");

        postWith(worker, "/api/bookings/" + id + "/accept");

        // Start OTP must only be issued once the worker is on the way.
        expect(postWithRaw(worker, "/api/bookings/" + id + "/start-code", Map.of()), 409);
    }

    @Test
    void workerCannotCompleteWithoutBeingInProgress() throws Exception {
        UserAccount customer = newCustomer("+919800000009", true);
        UserAccount worker = newEligibleWorker("+919800000010");

        JsonNode created = createBooking(customer, worker, futureTime());
        long id = created.get("id").asLong();
        payFor(customer, id, "UPI");

        postWith(worker, "/api/bookings/" + id + "/accept");

        // The state guard fires before the OTP is even checked.
        expect(postWithRaw(worker, "/api/bookings/" + id + "/complete", Map.of("code", "000000")), 409);
    }

    @Test
    void incompleteProfileCannotCreateBooking() throws Exception {
        UserAccount customer = newCustomer("+919800000011", false);
        UserAccount worker = newEligibleWorker("+919800000012");

        JsonNode error = expect(postBooking(
                customer, worker, futureTime()), 409);
        assertThat(error.get("message").asText()).contains("Complete your profile");
    }

    @Test
    void bookingWithPastScheduledTimeIsRejected() throws Exception {
        UserAccount customer = newCustomer("+919800000013", true);
        UserAccount worker = newEligibleWorker("+919800000014");

        String past = LocalDateTime.now().minusHours(2).format(DateTimeFormatter.ISO_LOCAL_DATE_TIME);
        JsonNode error = expect(postBooking(customer, worker, past), 400);
        assertThat(error.get("message").asText()).contains("future");
    }

    @Test
    void bookingWithMalformedScheduledTimeIsRejected() throws Exception {
        UserAccount customer = newCustomer("+919800000015", true);
        UserAccount worker = newEligibleWorker("+919800000016");

        JsonNode error = expect(postBooking(customer, worker, "not-a-date"), 400);
        assertThat(error.get("message").asText()).contains("Invalid scheduled time format");
    }

    // ---- helpers ----

    private UserAccount newCustomer(String phone, boolean profileCompleted) {
        UserAccount user = new UserAccount(
                "Test Customer", "customer@example.com", "password", phone, Role.CUSTOMER);
        user.setProfileCompleted(profileCompleted);
        return users.save(user);
    }

    private UserAccount newEligibleWorker(String phone) {
        UserAccount worker = new UserAccount("Test Worker", "", "password", phone, Role.WORKER);
        users.save(worker);
        WorkerProfile profile = new WorkerProfile(worker);
        profile.acceptConsent();
        profile.submitKyc("kyc-" + phone);
        profile.submitPan("ABCDE1234F", worker.getName(), "pan-" + phone);
        profile.submitSelfie("selfie-" + phone);
        profile.submitAddress("12 Main Road", "12 Main Road", "Kolkata", "West Bengal", PIN, "addr-" + phone);
        profile.submitPoliceVerification("police-" + phone);
        profile.setPayout("bank", worker.getName(), "1234", "HDFC0000001", "");
        profile.submitServiceReadiness(
                "Bathroom Cleaning, Kitchen Cleaning", PIN + ",712101", "2 years", "anytime", true);
        profile.approve();
        profile.setAvailability(AvailabilityStatus.AVAILABLE);
        profiles.save(profile);
        return worker;
    }

    private String futureTime() {
        return LocalDateTime.now().plusDays(1).withHour(10).withMinute(0)
                .format(DateTimeFormatter.ISO_LOCAL_DATE_TIME);
    }

    private JsonNode createBooking(UserAccount customer, UserAccount worker, String scheduledFor) throws Exception {
        return expect(postBooking(customer, worker, scheduledFor), 200);
    }

    /** Completes the mock-gateway payment for a booking (intent + pay). */
    private void payFor(UserAccount customer, long bookingId, String method) throws Exception {
        JsonNode intent = postWith(customer, "/api/bookings/" + bookingId + "/pay-intent",
                Map.of("method", method));
        postWith(customer, "/api/bookings/" + bookingId + "/pay", Map.of(
                "intentId", intent.get("intentId").asText(),
                "method", method,
                "upiId", "customer@upi"));
    }

    private ResultActions postBooking(UserAccount customer, UserAccount worker, String scheduledFor) throws Exception {
        return mockMvc.perform(post("/api/bookings")
                .header("Authorization", "Bearer " + jwt.issue(customer))
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(Map.of(
                        "services", java.util.List.of("Bathroom Cleaning"),
                        "address", "12 Main Road",
                        "pinCode", PIN,
                        "scheduledFor", scheduledFor,
                        "durationMinutes", 60,
                        "optionLabel", "Standard service"))));
    }

    private JsonNode postWith(UserAccount user, String path) throws Exception {
        return expect(post(path)
                .header("Authorization", "Bearer " + jwt.issue(user)), 200);
    }

    private JsonNode postWith(UserAccount user, String path, Map<String, Object> body) throws Exception {
        return expect(postWithRaw(user, path, body), 200);
    }

    private ResultActions postWithRaw(UserAccount user, String path, Map<String, Object> body) throws Exception {
        return mockMvc.perform(post(path)
                .header("Authorization", "Bearer " + jwt.issue(user))
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(body)));
    }

    private String latestOtpFor(UserAccount customer) throws Exception {
        MvcResult result = mockMvc.perform(get("/api/notifications")
                .header("Authorization", "Bearer " + jwt.issue(customer)))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode notifications = objectMapper.readTree(result.getResponse().getContentAsString());
        for (JsonNode notification : notifications) {
            Matcher matcher = OTP_PATTERN.matcher(notification.get("message").asText());
            if (matcher.find()) {
                return matcher.group(1);
            }
        }
        throw new AssertionError("No OTP notification found for customer. Got: " + notifications);
    }

    private JsonNode expect(MockHttpServletRequestBuilder builder, int expectedStatus) throws Exception {
        return expect(mockMvc.perform(builder), expectedStatus);
    }

    private JsonNode expect(ResultActions actions, int expectedStatus) throws Exception {
        MvcResult result = actions
                .andExpect(status().is(expectedStatus))
                .andReturn();
        return objectMapper.readTree(result.getResponse().getContentAsString());
    }
}
