package com.makeitquick.security;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Map;
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
 * End-to-end tests for the unified customer authentication flow against an
 * in-memory H2 database: send OTP, verify OTP, complete profile, JWT session,
 * profile management and logout revocation.
 */
@SpringBootTest(properties = {
        "spring.datasource.url=jdbc:h2:mem:authflow;MODE=MySQL;DB_CLOSE_DELAY=-1",
        "spring.datasource.driver-class-name=org.h2.Driver",
        "spring.datasource.username=sa",
        "spring.datasource.password=",
        "spring.jpa.hibernate.ddl-auto=create-drop",
        "app.admin.email=",
        "app.admin.password=",
        "app.sms.enabled=false"
})
@AutoConfigureMockMvc
class AuthFlowIT {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void sendOtpReturnsCodeAndExpiry() throws Exception {
        JsonNode sent = sendOtp("+91 98765 43210");

        assertThat(sent.get("message").asText()).isEqualTo("OTP sent");
        assertThat(sent.get("phone").asText()).isEqualTo("+919876543210");
        assertThat(sent.get("expiresInSeconds").asInt()).isEqualTo(300);
        assertThat(sent.get("devOtp").asText()).matches("\\d{6}");
    }

    @Test
    void sendOtpNormalizesBareIndianNumber() throws Exception {
        JsonNode sent = sendOtp("9876500111");
        assertThat(sent.get("phone").asText()).isEqualTo("+919876500111");
    }

    @Test
    void sendOtpRejectsInvalidNumbers() throws Exception {
        JsonNode error = expect(performPost("/api/v1/auth/send-otp", Map.of("phone", "123")), 400);
        assertThat(error.get("message").asText()).contains("valid 10-digit");
    }

    @Test
    void sendOtpIsRateLimited() throws Exception {
        String phone = "+919999000001";
        for (int i = 0; i < 4; i++) {
            postJson("/api/v1/auth/send-otp", Map.of("phone", phone));
        }
        JsonNode tooMany = expect(performPost("/api/v1/auth/send-otp", Map.of("phone", phone)), 429);
        assertThat(tooMany.get("message").asText()).contains("Too many OTP requests");
    }

    @Test
    void verifyOtpRejectsWrongCodeAndLocksAfterFiveAttempts() throws Exception {
        JsonNode sent = sendOtp("+919999000002");
        String phone = sent.get("phone").asText();
        String wrong = wrongCode(sent.get("devOtp").asText());

        for (int i = 0; i < 4; i++) {
            JsonNode error = expect(performPost("/api/v1/auth/verify-otp",
                    Map.of("phone", phone, "otp", wrong)), 401);
            assertThat(error.get("message").asText()).isEqualTo("Incorrect OTP. Try again.");
        }
        JsonNode locked = expect(performPost("/api/v1/auth/verify-otp",
                Map.of("phone", phone, "otp", wrong)), 401);
        assertThat(locked.get("message").asText())
                .isEqualTo("Maximum OTP attempts reached. Request a new OTP.");
    }

    @Test
    void verifyOtpRejectsMissingOrExpiredChallenge() throws Exception {
        JsonNode error = expect(performPost("/api/v1/auth/verify-otp",
                Map.of("phone", "+919999000003", "otp", "123456")), 400);
        assertThat(error.get("message").asText())
                .isEqualTo("OTP is invalid or expired. Request a new OTP.");
    }

    @Test
    void newCustomerRegistersThroughPendingToken() throws Exception {
        String phone = "+919999000004";
        JsonNode pending = verifyNewCustomer(phone);

        assertThat(pending.get("existing").asBoolean()).isFalse();
        assertThat(pending.get("pendingToken").asText()).isNotBlank();

        JsonNode created = postJson("/api/v1/auth/complete-profile", Map.of(
                "pendingToken", pending.get("pendingToken").asText(),
                "name", "Asha Devi",
                "email", "asha@example.com",
                "gender", "FEMALE",
                "dob", "1995-04-12"));
        assertThat(created.get("existing").asBoolean()).isTrue();
        assertThat(created.get("token").asText()).isNotBlank();
        assertThat(created.get("role").asText()).isEqualTo("CUSTOMER");
        assertThat(created.get("name").asText()).isEqualTo("Asha Devi");
        assertThat(created.get("phone").asText()).isEqualTo(phone);
        assertThat(created.get("profileComplete").asBoolean()).isTrue();
    }

    @Test
    void completeProfileStoresProfilePhoto() throws Exception {
        JsonNode pending = verifyNewCustomer("+919999000005");
        String photo = "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q==";
        JsonNode created = postJson("/api/v1/auth/complete-profile", Map.of(
                "pendingToken", pending.get("pendingToken").asText(),
                "name", "Photo Customer",
                "profileImage", photo));
        assertThat(created.get("token").asText()).isNotBlank();

        JsonNode profile = getProfile(created.get("token").asText());
        assertThat(profile.get("profileImage").asText()).isEqualTo(photo);
    }

    @Test
    void completeProfileRejectsBlankName() throws Exception {
        JsonNode pending = verifyNewCustomer("+919999000006");
        JsonNode error = expect(performPost("/api/v1/auth/complete-profile", Map.of(
                "pendingToken", pending.get("pendingToken").asText(),
                "name", "   ")), 400);
        assertThat(error.get("message").asText()).isEqualTo("Enter your full name.");
    }

    @Test
    void completeProfileRejectsUsedToken() throws Exception {
        JsonNode pending = verifyNewCustomer("+919999000007");
        String token = pending.get("pendingToken").asText();
        postJson("/api/v1/auth/complete-profile", Map.of(
                "pendingToken", token, "name", "First Try"));

        JsonNode error = expect(performPost("/api/v1/auth/complete-profile", Map.of(
                "pendingToken", token, "name", "Second Try")), 400);
        assertThat(error.get("message").asText())
                .isEqualTo("Verification expired or already used. Request a new OTP.");
    }

    @Test
    void completeProfileRejectsDuplicatePhone() throws Exception {
        String phone = "+919999000008";
        JsonNode firstPending = verifyNewCustomer(phone);
        JsonNode secondPending = verifyNewCustomer(phone);
        postJson("/api/v1/auth/complete-profile", Map.of(
                "pendingToken", firstPending.get("pendingToken").asText(), "name", "Original"));

        JsonNode error = expect(performPost("/api/v1/auth/complete-profile", Map.of(
                "pendingToken", secondPending.get("pendingToken").asText(), "name", "Duplicate")), 409);
        assertThat(error.get("message").asText())
                .isEqualTo("An account already exists for this phone number. Sign in instead.");
    }

    @Test
    void partnerPhoneCanAlsoRegisterAsCustomer() throws Exception {
        String phone = "+919999000014";

        // 1. Register as a partner first.
        JsonNode signupSent = postJson("/api/auth/partner/otp/signup/start",
                Map.of("name", "Partner First", "phone", phone));
        JsonNode partnerSigned = postJson("/api/auth/partner/otp/verify", Map.of(
                "phone", signupSent.get("phone").asText(),
                "purpose", "signup",
                "otp", signupSent.get("devOtp").asText()));
        assertThat(partnerSigned.get("role").asText()).isEqualTo("WORKER");

        // 2. The customer flow must NOT sign the partner account in; it returns
        //    a pending registration so a separate customer account is created.
        JsonNode customerSent = sendOtp(phone);
        JsonNode pending = postJson("/api/v1/auth/verify-otp", Map.of(
                "phone", customerSent.get("phone").asText(),
                "otp", customerSent.get("devOtp").asText()));
        assertThat(pending.get("existing").asBoolean()).isFalse();
        assertThat(pending.get("pendingToken").asText()).isNotBlank();

        // 3. Complete the customer profile; both accounts now coexist.
        JsonNode created = postJson("/api/v1/auth/complete-profile", Map.of(
                "pendingToken", pending.get("pendingToken").asText(),
                "name", "Customer Second",
                "email", "customer@example.com"));
        assertThat(created.get("role").asText()).isEqualTo("CUSTOMER");
        assertThat(created.get("phone").asText()).isEqualTo(phone);

        // 4. The partner account still signs in as a partner.
        JsonNode loginSent = postJson("/api/auth/partner/otp/login/start", Map.of("phone", phone));
        JsonNode partnerAgain = postJson("/api/auth/partner/otp/verify", Map.of(
                "phone", phone,
                "purpose", "login",
                "otp", loginSent.get("devOtp").asText()));
        assertThat(partnerAgain.get("role").asText()).isEqualTo("WORKER");
    }

    @Test
    void customerPhoneCanAlsoRegisterAsPartner() throws Exception {
        String phone = "+919999000015";
        registerCustomer(phone, "Customer First");

        // Customer sign-in still resolves to the customer account.
        JsonNode customerSent = sendOtp(phone);
        JsonNode customerBack = postJson("/api/v1/auth/verify-otp", Map.of(
                "phone", phone,
                "otp", customerSent.get("devOtp").asText()));
        assertThat(customerBack.get("existing").asBoolean()).isTrue();
        assertThat(customerBack.get("role").asText()).isEqualTo("CUSTOMER");

        // Partner signup with the same number must create a separate account.
        JsonNode signupSent = postJson("/api/auth/partner/otp/signup/start",
                Map.of("name", "Partner Later", "phone", phone));
        JsonNode partnerSigned = postJson("/api/auth/partner/otp/verify", Map.of(
                "phone", signupSent.get("phone").asText(),
                "purpose", "signup",
                "otp", signupSent.get("devOtp").asText()));
        assertThat(partnerSigned.get("role").asText()).isEqualTo("WORKER");
    }

    @Test
    void existingCustomerSignsInDirectly() throws Exception {
        String phone = "+919999000009";
        String token = registerCustomer(phone, "Rekha Singh");

        JsonNode sent = sendOtp(phone);
        JsonNode signedIn = postJson("/api/v1/auth/verify-otp", Map.of(
                "phone", sent.get("phone").asText(),
                "otp", sent.get("devOtp").asText()));

        assertThat(signedIn.get("existing").asBoolean()).isTrue();
        assertThat(signedIn.get("token").asText()).isNotBlank().isNotEqualTo(token);
        assertThat(signedIn.get("name").asText()).isEqualTo("Rekha Singh");
        assertThat(signedIn.get("role").asText()).isEqualTo("CUSTOMER");
    }

    @Test
    void sessionEndpointAcceptsJwt() throws Exception {
        String token = registerCustomer("+919999000010", "Session User");
        JsonNode session = expect(get("/api/auth/session")
                .header("Authorization", "Bearer " + token), 200);
        assertThat(session.get("role").asText()).isEqualTo("CUSTOMER");
        assertThat(session.get("name").asText()).isEqualTo("Session User");
        assertThat(session.get("phone").asText()).isEqualTo("+919999000010");
    }

    @Test
    void logoutRevokesJwt() throws Exception {
        String token = registerCustomer("+919999000011", "Logout User");

        expect(post("/api/auth/logout")
                .header("Authorization", "Bearer " + token), 200);

        JsonNode error = expect(get("/api/auth/session")
                .header("Authorization", "Bearer " + token), 401);
        assertThat(error.get("message").asText()).isEqualTo("Please sign in");
    }

    @Test
    void protectedEndpointsRejectMissingToken() throws Exception {
        expect(get("/api/customer/profile"), 401);
    }

    @Test
    void profileGetAndUpdate() throws Exception {
        String token = registerCustomer("+919999000012", "Profile User");

        JsonNode profile = getProfile(token);
        assertThat(profile.get("name").asText()).isEqualTo("Profile User");
        assertThat(profile.get("phone").asText()).isEqualTo("+919999000012");
        assertThat(profile.get("profileComplete").asBoolean()).isTrue();

        JsonNode updated = expect(put("/api/customer/profile")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(Map.of(
                        "name", "Profile Updated",
                        "email", "profile@example.com",
                        "gender", "OTHER",
                        "dob", "1990-01-01"))), 200);
        assertThat(updated.get("name").asText()).isEqualTo("Profile Updated");
        assertThat(updated.get("gender").asText()).isEqualTo("OTHER");
        assertThat(updated.get("dob").asText()).isEqualTo("1990-01-01");
        assertThat(updated.get("email").asText()).isEqualTo("profile@example.com");
    }

    @Test
    void profileRejectsCorruptPhoto() throws Exception {
        String token = registerCustomer("+919999000013", "Photo Reject");
        JsonNode error = expect(put("/api/customer/profile")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(Map.of(
                        "name", "Photo Reject",
                        "profileImage", "data:image/jpeg;base64,!!not-base64!!"))), 400);
        assertThat(error.get("message").asText()).isNotBlank();
    }

    // ---- helpers ----

    private JsonNode sendOtp(String phone) throws Exception {
        JsonNode sent = postJson("/api/v1/auth/send-otp", Map.of("phone", phone));
        assertThat(sent.get("devOtp").asText()).matches("\\d{6}");
        return sent;
    }

    private JsonNode verifyNewCustomer(String phone) throws Exception {
        JsonNode sent = sendOtp(phone);
        return postJson("/api/v1/auth/verify-otp", Map.of(
                "phone", sent.get("phone").asText(),
                "otp", sent.get("devOtp").asText()));
    }

    private String registerCustomer(String phone, String name) throws Exception {
        JsonNode pending = verifyNewCustomer(phone);
        JsonNode created = postJson("/api/v1/auth/complete-profile", Map.of(
                "pendingToken", pending.get("pendingToken").asText(),
                "name", name));
        assertThat(created.get("token").asText()).isNotBlank();
        return created.get("token").asText();
    }

    private JsonNode getProfile(String token) throws Exception {
        return expect(get("/api/customer/profile")
                .header("Authorization", "Bearer " + token), 200);
    }

    private JsonNode postJson(String path, Object body) throws Exception {
        return expect(performPost(path, body), 200);
    }

    private ResultActions performPost(String path, Object body) throws Exception {
        return mockMvc.perform(post(path)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(body)));
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

    private static String wrongCode(String code) {
        return code.equals("000000") ? "000001" : "000000";
    }
}
