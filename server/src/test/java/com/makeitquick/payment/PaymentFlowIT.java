package com.makeitquick.payment;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.makeitquick.booking.Booking;
import com.makeitquick.operations.AvailabilityStatus;
import com.makeitquick.security.JwtService;
import com.makeitquick.security.Role;
import com.makeitquick.security.UserAccount;
import com.makeitquick.security.UserRepository;
import com.makeitquick.worker.WorkerProfile;
import com.makeitquick.worker.WorkerProfileRepository;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
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
 * Verifies the payment workflow story (CUS-US-002): booking creation stays
 * unpaid and unassigned, the mock gateway marks the booking paid, partner
 * assignment fires only after payment, declined and duplicate attempts never
 * create duplicate bookings, and unpaid sessions expire.
 */
@SpringBootTest(properties = {
        "spring.datasource.url=jdbc:h2:mem:paymentflow;MODE=MySQL;DB_CLOSE_DELAY=-1",
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
class PaymentFlowIT {

    private static final String PIN = "712235";

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

    @BeforeEach
    void cleanDatabase() {
        new org.springframework.transaction.support.TransactionTemplate(txManager).executeWithoutResult(status -> {
            em.createQuery("delete from Payment").executeUpdate();
            em.createQuery("delete from BookingEvent").executeUpdate();
            em.createQuery("delete from BookingService").executeUpdate();
            em.createQuery("delete from Booking").executeUpdate();
            em.createQuery("delete from AppNotification").executeUpdate();
            em.createQuery("delete from Session").executeUpdate();
            em.createQuery("delete from WorkerProfile").executeUpdate();
            em.createQuery("delete from UserAccount").executeUpdate();
            em.clear();
        });
    }

    @Test
    void bookingIsCreatedUnpaidWithCapturedAmount() throws Exception {
        UserAccount customer = newCustomer("+919800000031", true);

        JsonNode created = createBooking(customer, futureTime());
        assertThat(created.get("paymentStatus").asText()).isEqualTo("UNPAID");
        assertThat(created.get("paymentAmountPaise").asInt()).isEqualTo(188564);
        assertThat(created.get("worker").asText()).isEqualTo("Unassigned");
        assertThat(created.get("status").asText()).isEqualTo("REQUESTED");
    }

    @Test
    void paymentWithUpiMarksPaidAndAssignsWorker() throws Exception {
        UserAccount customer = newCustomer("+919800000032", true);
        UserAccount worker = newEligibleWorker("+919800000033");

        JsonNode created = createBooking(customer, futureTime());
        long id = created.get("id").asLong();

        JsonNode intent = expect(post("/api/bookings/" + id + "/pay-intent")
                .header("Authorization", "Bearer " + jwt.issue(customer))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"method\":\"UPI\"}"), 200);
        assertThat(intent.get("intentId").asLong()).isPositive();
        assertThat(intent.get("amountPaise").asLong()).isEqualTo(188564);

        JsonNode paid = expect(post("/api/bookings/" + id + "/pay")
                .header("Authorization", "Bearer " + jwt.issue(customer))
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(Map.of(
                        "intentId", intent.get("intentId").asText(),
                        "method", "UPI",
                        "upiId", "riya@upi"))), 200);
        assertThat(paid.get("payment").get("status").asText()).isEqualTo("PAID");
        assertThat(paid.get("payment").get("reference").asText()).isNotBlank();

        JsonNode detail = expect(mockMvc.perform(get("/api/bookings/" + id)
                .header("Authorization", "Bearer " + jwt.issue(customer))), 200);
        assertThat(detail.get("paymentStatus").asText()).isEqualTo("PAID");
        assertThat(detail.get("paymentMethod").asText()).isEqualTo("UPI");
        assertThat(detail.get("paidAt").asText()).isNotBlank();
        assertThat(detail.get("status").asText()).isEqualTo("ASSIGNED");
        assertThat(detail.get("worker").asText()).isEqualTo(worker.getName());
    }

    @Test
    void paymentWithoutEligibleWorkerStaysRequestedButPaid() throws Exception {
        UserAccount customer = newCustomer("+919800000034", true);

        JsonNode created = createBooking(customer, futureTime());
        long id = created.get("id").asLong();
        payFor(customer, id, "UPI");

        JsonNode detail = expect(mockMvc.perform(get("/api/bookings/" + id)
                .header("Authorization", "Bearer " + jwt.issue(customer))), 200);
        assertThat(detail.get("paymentStatus").asText()).isEqualTo("PAID");
        assertThat(detail.get("status").asText()).isEqualTo("REQUESTED");
        assertThat(detail.get("worker").asText()).isEqualTo("Unassigned");
    }

    @Test
    void cardEnding0000IsDeclinedAndBookingStaysUnpaid() throws Exception {
        UserAccount customer = newCustomer("+919800000035", true);

        JsonNode created = createBooking(customer, futureTime());
        long id = created.get("id").asLong();

        JsonNode intent = expect(post("/api/bookings/" + id + "/pay-intent")
                .header("Authorization", "Bearer " + jwt.issue(customer))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"method\":\"CARD\"}"), 200);

        JsonNode error = expect(post("/api/bookings/" + id + "/pay")
                .header("Authorization", "Bearer " + jwt.issue(customer))
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(Map.of(
                        "intentId", intent.get("intentId").asText(),
                        "method", "CARD",
                        "cardLast4", "0000"))), 402);
        assertThat(error.get("message").asText()).contains("declined");

        JsonNode detail = expect(mockMvc.perform(get("/api/bookings/" + id)
                .header("Authorization", "Bearer " + jwt.issue(customer))), 200);
        assertThat(detail.get("paymentStatus").asText()).isEqualTo("UNPAID");
        assertThat(detail.get("status").asText()).isEqualTo("REQUESTED");
    }

    @Test
    void retryAfterDeclineCreatesNoDuplicateBooking() throws Exception {
        UserAccount customer = newCustomer("+919800000036", true);

        JsonNode created = createBooking(customer, futureTime());
        long id = created.get("id").asLong();
        payFor(customer, id, "CARD", "0000", "UPI");

        JsonNode detail = expect(mockMvc.perform(get("/api/bookings/" + id)
                .header("Authorization", "Bearer " + jwt.issue(customer))), 200);
        assertThat(detail.get("paymentStatus").asText()).isEqualTo("PAID");
        assertThat(detail.get("paymentMethod").asText()).isEqualTo("UPI");

        List<?> list = objectMapper.readTree(mockMvc.perform(get("/api/bookings")
                .header("Authorization", "Bearer " + jwt.issue(customer)))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString())
                .findValues("id");
        assertThat(list).hasSize(1);
    }

    @Test
    void replayingTheSameIntentIsRejected() throws Exception {
        UserAccount customer = newCustomer("+919800000037", true);

        JsonNode created = createBooking(customer, futureTime());
        long id = created.get("id").asLong();
        JsonNode intent = payIntent(customer, id, "UPI");
        pay(customer, id, intent, "UPI");

        JsonNode error = expect(post("/api/bookings/" + id + "/pay")
                .header("Authorization", "Bearer " + jwt.issue(customer))
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(Map.of(
                        "intentId", intent.get("intentId").asText(),
                        "method", "UPI",
                        "upiId", "riya@upi"))), 409);
        assertThat(error.get("message").asText()).contains("already processed");
    }

    @Test
    void payingAlreadyPaidBookingIsConflict() throws Exception {
        UserAccount customer = newCustomer("+919800000038", true);

        JsonNode created = createBooking(customer, futureTime());
        long id = created.get("id").asLong();
        payFor(customer, id, "UPI");

        JsonNode error = expect(post("/api/bookings/" + id + "/pay-intent")
                .header("Authorization", "Bearer " + jwt.issue(customer))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"method\":\"UPI\"}"), 409);
        assertThat(error.get("message").asText()).contains("already paid");
    }

    @Test
    void secondActiveBookingIsRejected() throws Exception {
        UserAccount customer = newCustomer("+919800000039", true);

        createBooking(customer, futureTime());
        JsonNode error = expect(postBooking(customer, futureTime()), 409);
        assertThat(error.get("message").asText()).contains("active booking");
    }

    @Test
    void unpaidBookingExpiresAfterTimeout() throws Exception {
        UserAccount customer = newCustomer("+919800000040", true);

        JsonNode created = createBooking(customer, futureTime());
        long id = created.get("id").asLong();
        ageBooking(id);

        JsonNode error = expect(post("/api/bookings/" + id + "/pay-intent")
                .header("Authorization", "Bearer " + jwt.issue(customer))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"method\":\"UPI\"}"), 410);
        assertThat(error.get("message").asText()).contains("expired");
    }

    @Test
    void paymentEndpointReturnsLatestRecord() throws Exception {
        UserAccount customer = newCustomer("+919800000041", true);

        JsonNode created = createBooking(customer, futureTime());
        long id = created.get("id").asLong();

        JsonNode unpaid = expect(mockMvc.perform(get("/api/bookings/" + id + "/payment")
                .header("Authorization", "Bearer " + jwt.issue(customer))), 200);
        assertThat(unpaid.get("status").asText()).isEqualTo("UNPAID");

        payFor(customer, id, "UPI");
        JsonNode record = expect(mockMvc.perform(get("/api/bookings/" + id + "/payment")
                .header("Authorization", "Bearer " + jwt.issue(customer))), 200);
        assertThat(record.get("status").asText()).isEqualTo("PAID");
        assertThat(record.get("amountPaise").asLong()).isEqualTo(188564);
    }

    @Test
    void anotherCustomerCannotPayTheBooking() throws Exception {
        UserAccount owner = newCustomer("+919800000042", true);
        UserAccount stranger = newCustomer("+919800000043", true);

        JsonNode created = createBooking(owner, futureTime());
        long id = created.get("id").asLong();

        expect(post("/api/bookings/" + id + "/pay-intent")
                .header("Authorization", "Bearer " + jwt.issue(stranger))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"method\":\"UPI\"}"), 404);
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

    private JsonNode createBooking(UserAccount customer, String scheduledFor) throws Exception {
        return expect(postBooking(customer, scheduledFor), 200);
    }

    private ResultActions postBooking(UserAccount customer, String scheduledFor) throws Exception {
        return mockMvc.perform(post("/api/bookings")
                .header("Authorization", "Bearer " + jwt.issue(customer))
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(Map.of(
                        "services", List.of("Bathroom Cleaning"),
                        "address", "12 Main Road",
                        "pinCode", PIN,
                        "scheduledFor", scheduledFor,
                        "durationMinutes", 120,
                        "optionLabel", "Standard service"))));
    }

    private JsonNode payIntent(UserAccount customer, long bookingId, String method) throws Exception {
        return expect(post("/api/bookings/" + bookingId + "/pay-intent")
                .header("Authorization", "Bearer " + jwt.issue(customer))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"method\":\"" + method + "\"}"), 200);
    }

    private JsonNode pay(UserAccount customer, long bookingId, JsonNode intent, String method) throws Exception {
        return expect(post("/api/bookings/" + bookingId + "/pay")
                .header("Authorization", "Bearer " + jwt.issue(customer))
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(Map.of(
                        "intentId", intent.get("intentId").asText(),
                        "method", method,
                        "upiId", "riya@upi"))), 200);
    }

    /** Completes payment, optionally simulating a declined card first. */
    private void payFor(UserAccount customer, long bookingId, String method) throws Exception {
        pay(customer, bookingId, payIntent(customer, bookingId, method), method);
    }

    private void payFor(UserAccount customer, long bookingId, String declinedMethod,
                        String declinedCard, String successMethod) throws Exception {
        JsonNode declinedIntent = payIntent(customer, bookingId, declinedMethod);
        expect(post("/api/bookings/" + bookingId + "/pay")
                .header("Authorization", "Bearer " + jwt.issue(customer))
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(Map.of(
                        "intentId", declinedIntent.get("intentId").asText(),
                        "method", declinedMethod,
                        "cardLast4", declinedCard))), 402);
        pay(customer, bookingId, payIntent(customer, bookingId, successMethod), successMethod);
    }

    /** Pushes an unpaid booking's created-at back beyond the payment timeout. */
    private void ageBooking(long bookingId) {
        new org.springframework.transaction.support.TransactionTemplate(txManager).executeWithoutResult(status -> {
            em.createQuery("update Booking b set b.createdAt = :old where b.id = :id")
                    .setParameter("old", Instant.now().minus(PaymentService.UNPAID_TIMEOUT).minusSeconds(60))
                    .setParameter("id", bookingId)
                    .executeUpdate();
            em.clear();
        });
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
