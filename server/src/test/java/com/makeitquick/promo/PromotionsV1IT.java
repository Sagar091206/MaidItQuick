package com.makeitquick.promo;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.makeitquick.admin.settings.SettingRepository;
import com.makeitquick.booking.Booking;
import com.makeitquick.booking.BookingRepository;
import com.makeitquick.booking.BookingStatus;
import com.makeitquick.payment.PaymentStatus;
import com.makeitquick.security.JwtService;
import com.makeitquick.security.Role;
import com.makeitquick.security.UserAccount;
import com.makeitquick.security.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDateTime;

@SpringBootTest(properties = {
        "spring.datasource.url=jdbc:h2:mem:promotions_v1_test;MODE=MySQL;DB_CLOSE_DELAY=-1",
        "spring.datasource.driver-class-name=org.h2.Driver",
        "spring.datasource.username=sa",
        "spring.datasource.password=",
        "spring.jpa.hibernate.ddl-auto=create-drop",
        "app.admin.email=",
        "app.admin.password=",
        "app.sms.enabled=false",
        "app.uploads.directory=target/test-promos-uploads"
})
@AutoConfigureMockMvc
class PromotionsV1IT {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private UserRepository users;

    @Autowired
    private BookingRepository bookings;

    @Autowired
    private SettingRepository settings;

    @Autowired
    private PromoCodeRepository promoCodes;

    @Autowired
    private PromotionService promotionService;

    @Autowired
    private JwtService jwt;

    @Autowired
    private com.makeitquick.operations.ServiceAreaRepository serviceAreas;

    @Autowired
    private com.makeitquick.catalog.ServiceItemRepository services;

    @Autowired
    private com.makeitquick.catalog.ServiceAreaOfferingRepository offerings;

    @Autowired
    private org.springframework.jdbc.core.JdbcTemplate jdbc;

    private UserAccount admin;
    private UserAccount newCustomer;
    private UserAccount existingCustomer;

    @BeforeEach
    void setUp() {
        jdbc.execute("DELETE FROM app_notifications");
        jdbc.execute("DELETE FROM return_requests");
        jdbc.execute("DELETE FROM payments");
        jdbc.execute("DELETE FROM booking_events");
        jdbc.execute("DELETE FROM booking_services");
        jdbc.execute("DELETE FROM bookings");
        jdbc.execute("DELETE FROM promo_codes");
        jdbc.execute("DELETE FROM sessions");
        jdbc.execute("DELETE FROM users");

        com.makeitquick.operations.ServiceArea area = serviceAreas.findByPinCode("400001")
                .orElseGet(() -> serviceAreas.save(new com.makeitquick.operations.ServiceArea("400001", "Mumbai")));

        com.makeitquick.catalog.ServiceItem item = services.findByEnabledTrueAndNameIgnoreCase("Bathroom Cleaning").orElse(null);
        if (item != null && offerings.findByServiceAreaPinCodeAndServiceNameIgnoreCase("400001", "Bathroom Cleaning").isEmpty()) {
            offerings.save(new com.makeitquick.catalog.ServiceAreaOffering(area, item, 79900));
        }

        // Reset default first order setting to 20%
        promotionService.setFirstOrderDiscountPercentage(20);

        admin = users.save(new UserAccount("Admin User", "admin@example.com", "password", "+919800000001", Role.ADMIN));
        admin.setProfileCompleted(true);
        users.save(admin);

        newCustomer = users.save(new UserAccount("New Customer", "new@example.com", "password", "+919800000002", Role.CUSTOMER));
        newCustomer.setProfileCompleted(true);
        users.save(newCustomer);

        existingCustomer = users.save(new UserAccount("Existing Customer", "existing@example.com", "password", "+919800000003", Role.CUSTOMER));
        existingCustomer.setProfileCompleted(true);
        users.save(existingCustomer);

        // Give existing customer a completed booking
        Booking completed = new Booking(existingCustomer, "Bathroom Cleaning", "123 Street",
                LocalDateTime.now().plusDays(1).toString(),
                "400001", 60, "Standard", "", 0, "");
        completed.setPaymentAmountPaise(79900);
        completed.setStatus(BookingStatus.COMPLETED);
        completed.markPaid("UPI", 79900);
        bookings.save(completed);
    }

    // ==========================================
    // 1. FIRST ORDER DISCOUNT TESTS
    // ==========================================

    @Test
    @DisplayName("1. New customer receives 20% default first-order discount")
    void newCustomerReceivesDefault20PercentFirstOrderDiscount() throws Exception {
        String res = mockMvc.perform(get("/api/booking/quote")
                        .param("services", "Bathroom Cleaning")
                        .param("durationMinutes", "60")
                        .header("Authorization", "Bearer " + jwt.issue(newCustomer)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();

        JsonNode json = objectMapper.readTree(res);
        assertThat(json.get("discountType").asText()).isEqualTo("FIRST_ORDER");
        assertThat(json.get("discountPercentage").asInt()).isEqualTo(20);

        long subtotal = json.get("subtotalPaise").asLong();
        long expectedDiscount = Math.round(subtotal * 0.20);
        assertThat(json.get("discountPaise").asLong()).isEqualTo(expectedDiscount);
    }

    @Test
    @DisplayName("2. Admin changes percentage and new percentage is used immediately")
    void adminChangesPercentageAndNewPercentageIsUsed() throws Exception {
        // Change from 20% to 15% via Admin API
        mockMvc.perform(put("/api/v1/admin/promos/first-order")
                        .header("Authorization", "Bearer " + jwt.issue(admin))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"percentage\": 15}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.percentage").value(15));

        // Verify quote uses 15%
        String res = mockMvc.perform(get("/api/booking/quote")
                        .param("services", "Bathroom Cleaning")
                        .param("durationMinutes", "60")
                        .header("Authorization", "Bearer " + jwt.issue(newCustomer)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();

        JsonNode json = objectMapper.readTree(res);
        assertThat(json.get("discountType").asText()).isEqualTo("FIRST_ORDER");
        assertThat(json.get("discountPercentage").asInt()).isEqualTo(15);
    }

    @Test
    @DisplayName("3. Customer who already completed/used their first eligible order does not receive it again")
    void customerWithCompletedOrderDoesNotReceiveFirstOrderDiscount() throws Exception {
        String res = mockMvc.perform(get("/api/booking/quote")
                        .param("services", "Bathroom Cleaning")
                        .param("durationMinutes", "60")
                        .header("Authorization", "Bearer " + jwt.issue(existingCustomer)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();

        JsonNode json = objectMapper.readTree(res);
        assertThat(json.get("discountType").asText()).isEqualTo("NONE");
        assertThat(json.get("discountPercentage").asInt()).isZero();
        assertThat(json.get("discountPaise").asLong()).isZero();
    }

    @Test
    @DisplayName("4. Failed payment or unpaid booking does not incorrectly consume the first-order benefit")
    void failedOrUnpaidBookingDoesNotConsumeFirstOrderDiscount() throws Exception {
        // Customer creates a booking that was cancelled/unpaid
        Booking unpaidBooking = new Booking(newCustomer, "Deep Cleaning", "Some Address",
                LocalDateTime.now().plusDays(2).toString(),
                "400001", 60, "Standard", "", 0, "");
        unpaidBooking.setStatus(BookingStatus.CANCELLED);
        bookings.save(unpaidBooking);

        // Customer is still eligible for first order discount
        String res = mockMvc.perform(get("/api/booking/quote")
                        .param("services", "Bathroom Cleaning")
                        .param("durationMinutes", "60")
                        .header("Authorization", "Bearer " + jwt.issue(newCustomer)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();

        JsonNode json = objectMapper.readTree(res);
        assertThat(json.get("discountType").asText()).isEqualTo("FIRST_ORDER");
        assertThat(json.get("discountPercentage").asInt()).isEqualTo(20);
    }

    @Test
    @DisplayName("5. Backend calculates the discount independently of Flutter input")
    void backendCalculatesDiscountIndependently() throws Exception {
        String schedule = LocalDateTime.now().plusDays(3).withNano(0).toString();
        String bookingPayload = String.format("""
                {
                    "services": ["Bathroom Cleaning"],
                    "address": "Flat 101, Test Lane",
                    "pinCode": "400001",
                    "scheduledFor": "%s",
                    "durationMinutes": 60,
                    "specialInstructions": "None"
                }
                """, schedule);

        String res = mockMvc.perform(post("/api/bookings")
                        .header("Authorization", "Bearer " + jwt.issue(newCustomer))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(bookingPayload))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();

        JsonNode json = objectMapper.readTree(res);
        // Server assigned discountPaise automatically
        assertThat(json.get("discountPaise").asLong()).isGreaterThan(0);
    }

    // ==========================================
    // 2. PROMO CODE TESTS
    // ==========================================

    @Test
    @DisplayName("6. Admin can create promo code")
    void adminCanCreatePromoCode() throws Exception {
        String payload = """
                {
                    "code": "FESTIVE25",
                    "discountPercentage": 25,
                    "enabled": true,
                    "description": "Festive 25% discount"
                }
                """;

        mockMvc.perform(post("/api/v1/admin/promos")
                        .header("Authorization", "Bearer " + jwt.issue(admin))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(payload))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.code").value("FESTIVE25"))
                .andExpect(jsonPath("$.data.discountPercentage").value(25))
                .andExpect(jsonPath("$.data.enabled").value(true));

        assertThat(promoCodes.findByCodeIgnoreCase("FESTIVE25")).isPresent();
    }

    @Test
    @DisplayName("7. Active promo code works")
    void activePromoCodeWorks() throws Exception {
        promoCodes.save(new PromoCode("SAVE30", 30, true, "30% off"));

        String res = mockMvc.perform(get("/api/booking/quote")
                        .param("services", "Bathroom Cleaning")
                        .param("durationMinutes", "60")
                        .param("promoCode", "SAVE30")
                        .header("Authorization", "Bearer " + jwt.issue(existingCustomer)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();

        JsonNode json = objectMapper.readTree(res);
        assertThat(json.get("discountType").asText()).isEqualTo("PROMO_CODE");
        assertThat(json.get("promoCode").asText()).isEqualTo("SAVE30");
        assertThat(json.get("discountPercentage").asInt()).isEqualTo(30);

        long subtotal = json.get("subtotalPaise").asLong();
        long expected = Math.round(subtotal * 0.30);
        assertThat(json.get("discountPaise").asLong()).isEqualTo(expected);
    }

    @Test
    @DisplayName("8. Inactive promo code does not work (throws 400)")
    void inactivePromoCodeDoesNotWork() throws Exception {
        promoCodes.save(new PromoCode("OFFLINE15", 15, false, "Disabled code"));

        mockMvc.perform(get("/api/booking/quote")
                        .param("services", "Bathroom Cleaning")
                        .param("durationMinutes", "60")
                        .param("promoCode", "OFFLINE15")
                        .header("Authorization", "Bearer " + jwt.issue(newCustomer)))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("9. Duplicate promo code is rejected with 400")
    void duplicatePromoCodeIsRejected() throws Exception {
        promoCodes.save(new PromoCode("UNIQUE20", 20, true, "First instance"));

        String duplicatePayload = """
                {
                    "code": "unique20",
                    "discountPercentage": 25,
                    "enabled": true
                }
                """;

        mockMvc.perform(post("/api/v1/admin/promos")
                        .header("Authorization", "Bearer " + jwt.issue(admin))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(duplicatePayload))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("10. Invalid / non-existent promo code is rejected with 400")
    void invalidPromoCodeIsRejected() throws Exception {
        mockMvc.perform(get("/api/booking/quote")
                        .param("services", "Bathroom Cleaning")
                        .param("durationMinutes", "60")
                        .param("promoCode", "NONEXISTENT")
                        .header("Authorization", "Bearer " + jwt.issue(newCustomer)))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("11. Discount percentage is validated (1-100%)")
    void discountPercentageIsValidated() throws Exception {
        // 0% rejected
        mockMvc.perform(post("/api/v1/admin/promos")
                        .header("Authorization", "Bearer " + jwt.issue(admin))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"code\":\"ZERO\",\"discountPercentage\":0}"))
                .andExpect(status().is4xxClientError());

        // 101% rejected
        mockMvc.perform(post("/api/v1/admin/promos")
                        .header("Authorization", "Bearer " + jwt.issue(admin))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"code\":\"OVER\",\"discountPercentage\":101}"))
                .andExpect(status().is4xxClientError());
    }

    @Test
    @DisplayName("12. Promo code is normalized and case-insensitive")
    void promoCodeIsNormalizedAndCaseInsensitive() throws Exception {
        promoCodes.save(new PromoCode("CLEAN20", 20, true, "Case test"));

        // Use lowercase with leading/trailing spaces
        String res = mockMvc.perform(get("/api/booking/quote")
                        .param("services", "Bathroom Cleaning")
                        .param("durationMinutes", "60")
                        .param("promoCode", "  clean20  ")
                        .header("Authorization", "Bearer " + jwt.issue(existingCustomer)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();

        JsonNode json = objectMapper.readTree(res);
        assertThat(json.get("promoCode").asText()).isEqualTo("CLEAN20");
        assertThat(json.get("discountType").asText()).isEqualTo("PROMO_CODE");
        assertThat(json.get("discountPercentage").asInt()).isEqualTo(20);
    }

    // ==========================================
    // 3. STACKING RULE TESTS
    // ==========================================

    @Test
    @DisplayName("13. Valid promo code takes precedence over first-order discount")
    void validPromoCodeTakesPrecedenceOverFirstOrder() throws Exception {
        promoCodes.save(new PromoCode("PROMO10", 10, true, "10% promo"));

        // newCustomer is eligible for 20% first order, but enters PROMO10 (10%)
        String res = mockMvc.perform(get("/api/booking/quote")
                        .param("services", "Bathroom Cleaning")
                        .param("durationMinutes", "60")
                        .param("promoCode", "PROMO10")
                        .header("Authorization", "Bearer " + jwt.issue(newCustomer)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();

        JsonNode json = objectMapper.readTree(res);
        // Promo code applied, NOT first order
        assertThat(json.get("discountType").asText()).isEqualTo("PROMO_CODE");
        assertThat(json.get("promoCode").asText()).isEqualTo("PROMO10");
        assertThat(json.get("discountPercentage").asInt()).isEqualTo(10);
    }

    @Test
    @DisplayName("14. Without promo code, eligible first-order discount applies")
    void withoutPromoCodeEligibleFirstOrderApplies() throws Exception {
        String res = mockMvc.perform(get("/api/booking/quote")
                        .param("services", "Bathroom Cleaning")
                        .param("durationMinutes", "60")
                        .param("promoCode", "")
                        .header("Authorization", "Bearer " + jwt.issue(newCustomer)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();

        JsonNode json = objectMapper.readTree(res);
        assertThat(json.get("discountType").asText()).isEqualTo("FIRST_ORDER");
        assertThat(json.get("discountPercentage").asInt()).isEqualTo(20);
    }

    @Test
    @DisplayName("15. Both discounts are never stacked")
    void discountsAreNeverStacked() throws Exception {
        promoCodes.save(new PromoCode("SAVE15", 15, true, "15% off"));

        String res = mockMvc.perform(get("/api/booking/quote")
                        .param("services", "Bathroom Cleaning")
                        .param("durationMinutes", "60")
                        .param("promoCode", "SAVE15")
                        .header("Authorization", "Bearer " + jwt.issue(newCustomer)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();

        JsonNode json = objectMapper.readTree(res);
        // If stacked, discount would be 20% + 15% = 35%
        // But rule is strictly 15% (promo precedence)
        assertThat(json.get("discountPercentage").asInt()).isEqualTo(15);
        long subtotal = json.get("subtotalPaise").asLong();
        long discount = json.get("discountPaise").asLong();
        assertThat(discount).isEqualTo(Math.round(subtotal * 0.15));
    }

    // ==========================================
    // 4. SECURITY / TAMPER-RESISTANCE TESTS
    // ==========================================

    @Test
    @DisplayName("16 & 17. Client cannot manipulate discount amount or final payment amount")
    void clientCannotManipulateDiscountOrFinalAmount() throws Exception {
        String schedule = LocalDateTime.now().plusDays(3).withNano(0).toString();
        String maliciousPayload = String.format("""
                {
                    "services": ["Bathroom Cleaning"],
                    "address": "Flat 101, Test Lane",
                    "pinCode": "400001",
                    "scheduledFor": "%s",
                    "durationMinutes": 60,
                    "discountPaise": 999999,
                    "totalPaise": 100,
                    "paymentAmountPaise": 100
                }
                """, schedule);

        String res = mockMvc.perform(post("/api/bookings")
                        .header("Authorization", "Bearer " + jwt.issue(newCustomer))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(maliciousPayload))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();

        JsonNode json = objectMapper.readTree(res);
        // Server ignores client-provided 999999 discount and 100 payment amount
        assertThat(json.get("paymentAmountPaise").asLong()).isGreaterThan(50000);
        assertThat(json.get("discountPaise").asLong()).isLessThan(20000);
    }
}
