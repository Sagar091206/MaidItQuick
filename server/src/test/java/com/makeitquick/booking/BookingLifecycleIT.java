package com.makeitquick.booking;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
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
 * <p>Verifies the customer booking journey: creation with automatic assignment
 * to an eligible worker, worker acceptance, on-the-way, OTP-gated start and
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
    void customerBookingIsAutoAssignedToEligibleWorker() throws Exception {
        UserAccount customer = newCustomer("+919800000001", true);
        UserAccount worker = newEligibleWorker("+919800000002");

        JsonNode created = createBooking(customer, worker, futureTime());
        assertThat(created.get("status").asText()).isEqualTo("ASSIGNED");
        assertThat(created.get("worker").asText()).isEqualTo(worker.getName());
    }

    @Test
    void customerCanCancelBeforeWorkerTravelsIncludingAccepted() throws Exception {
        UserAccount customer = newCustomer("+919800000003", true);
        UserAccount worker = newEligibleWorker("+919800000004");

        JsonNode created = createBooking(customer, worker, futureTime());
        long id = created.get("id").asLong();

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
    void workerCannotRequestStartOtpBeforeTravelling() throws Exception {
        UserAccount customer = newCustomer("+919800000007", true);
        UserAccount worker = newEligibleWorker("+919800000008");

        JsonNode created = createBooking(customer, worker, futureTime());
        long id = created.get("id").asLong();

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
