package com.makeitquick.catalog;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.makeitquick.security.JwtService;
import com.makeitquick.security.Role;
import com.makeitquick.security.UserAccount;
import com.makeitquick.security.UserRepository;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

/**
 * Verifies the service-discovery and pricing endpoints added for the customer
 * home dashboard story (CUS-US-001): service details, itemised quotes and the
 * duration calculation aligned with the catalog's default durations.
 */
@SpringBootTest(properties = {
        "spring.datasource.url=jdbc:h2:mem:servicediscovery;MODE=MySQL;DB_CLOSE_DELAY=-1",
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
class ServiceDiscoveryIT {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private UserRepository users;

    @Autowired
    private JwtService jwt;

    private UserAccount customer;

    @BeforeEach
    void setUp() {
        users.deleteAllInBatch();
        customer = users.save(new UserAccount(
                "Test Customer", "customer@example.com", "password", "+919800009001", Role.CUSTOMER));
        customer.setProfileCompleted(true);
        users.save(customer);
    }

    @Test
    void serviceListIncludesPresentationFields() throws Exception {
        JsonNode list = expect(mockMvc.perform(get("/api/services")), 200);
        JsonNode bathroom = null;
        for (JsonNode item : list) {
            if ("Bathroom Cleaning".equals(item.get("name").asText())) {
                bathroom = item;
                break;
            }
        }
        assertThat(bathroom).isNotNull();
        assertThat(bathroom.get("emoji").asText()).isEqualTo("🛁");
        assertThat(bathroom.get("description").asText()).isNotBlank();
        assertThat(bathroom.get("defaultDurationMinutes").asInt()).isGreaterThanOrEqualTo(30);
    }

    @Test
    void serviceDetailReturnsFullDetails() throws Exception {
        JsonNode item = expect(mockMvc.perform(get("/api/services/1")), 200);
        assertThat(item.get("name").asText()).isEqualTo("Bathroom Cleaning");
        assertThat(item.get("pricePaise").asInt()).isGreaterThan(0);
        assertThat(item.get("emoji").asText()).isEqualTo("🛁");
    }

    @Test
    void unknownServiceIs404() throws Exception {
        expect(mockMvc.perform(get("/api/services/999999")), 404);
    }

    @Test
    void quoteComputesItemisedTotalsForDuration() throws Exception {
        JsonNode quote = expect(mockMvc.perform(get("/api/booking/quote")
                .param("services", "Bathroom Cleaning")
                .param("durationMinutes", "120")
                .header("Authorization", "Bearer " + jwt.issue(customer))), 200);
        assertThat(quote.get("lines").size()).isEqualTo(1);
        assertThat(quote.get("lines").get(0).get("amountPaise").asLong()).isEqualTo(159800);
        assertThat(quote.get("subtotalPaise").asLong()).isEqualTo(159800);
        assertThat(quote.get("taxPaise").asLong()).isEqualTo(28764);
        assertThat(quote.get("convenienceFeePaise").asLong()).isZero();
        assertThat(quote.get("totalPaise").asLong()).isEqualTo(188564);
    }

    @Test
    void quoteAppliesValidatedPromoDiscount() throws Exception {
        JsonNode quote = expect(mockMvc.perform(get("/api/booking/quote")
                .param("services", "Bathroom Cleaning")
                .param("durationMinutes", "60")
                .param("promoCode", "WELCOME50")
                .header("Authorization", "Bearer " + jwt.issue(customer))), 200);
        assertThat(quote.get("discountPaise").asLong()).isEqualTo(5000);
        assertThat(quote.get("taxPaise").asLong()).isEqualTo(13482);
        assertThat(quote.get("totalPaise").asLong()).isEqualTo(88382);
    }

    @Test
    void quoteRejectsInvalidPromo() throws Exception {
        expect(mockMvc.perform(get("/api/booking/quote")
                .param("services", "Bathroom Cleaning")
                .param("durationMinutes", "60")
                .param("promoCode", "NOPE")
                .header("Authorization", "Bearer " + jwt.issue(customer))), 400);
    }

    @Test
    void quoteRequiresCustomerSession() throws Exception {
        expect(mockMvc.perform(get("/api/booking/quote")
                .param("services", "Bathroom Cleaning")
                .param("durationMinutes", "60")), 401);
    }

    @Test
    void durationCalculationSumsCatalogDefaults() throws Exception {
        JsonNode result = expect(mockMvc.perform(post("/api/booking/calculate-duration")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(
                        Map.of("services", List.of("Bathroom Cleaning", "Kitchen Cleaning"))))
                .header("Authorization", "Bearer " + jwt.issue(customer))), 200);
        assertThat(result.get("durationMinutes").asInt()).isEqualTo(150);
        assertThat(result.get("serviceCount").asInt()).isEqualTo(2);
    }

    private JsonNode expect(ResultActions actions, int expectedStatus) throws Exception {
        return objectMapper.readTree(actions
                .andExpect(status().is(expectedStatus))
                .andReturn()
                .getResponse()
                .getContentAsString());
    }
}
