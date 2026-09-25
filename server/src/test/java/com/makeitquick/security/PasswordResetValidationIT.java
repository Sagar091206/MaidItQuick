package com.makeitquick.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.makeitquick.admin.auth.ResetPasswordRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;

import java.time.Instant;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest(properties = {
        "spring.datasource.url=jdbc:h2:mem:password_reset_test;MODE=MySQL;DB_CLOSE_DELAY=-1",
        "spring.datasource.driver-class-name=org.h2.Driver",
        "spring.datasource.username=sa",
        "spring.datasource.password=",
        "spring.jpa.hibernate.ddl-auto=create-drop",
        "app.admin.email=",
        "app.admin.password=",
        "app.sms.enabled=false"
})
@AutoConfigureMockMvc
public class PasswordResetValidationIT {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper om;

    @Autowired
    private UserRepository users;

    @Autowired
    private ResetTokenRepository resets;

    @Autowired
    private PasswordEncoder passwordEncoder;

    private UserAccount adminUser;
    private String adminToken;

    @BeforeEach
    void setUp() {
        resets.deleteAll();
        users.deleteAll();

        adminUser = users.save(new UserAccount("Admin PW Test", "admin_pw_test@makeitquick.com", passwordEncoder.encode("OldPass123!"), Role.ADMIN));
        adminUser.setProfileCompleted(true);
        users.save(adminUser);

        // Raw 64-char token for reset
        adminToken = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_";
        resets.save(new ResetToken(adminToken, adminUser, Instant.now().plusSeconds(900)));
    }

    @Test
    @DisplayName("PasswordPolicy unit checks enforce all 5 criteria")
    void testPasswordPolicyCriteria() {
        assertThat(PasswordPolicy.hasMinLength("Pass123!")).isTrue();
        assertThat(PasswordPolicy.hasMinLength("Pass1!")).isFalse();

        assertThat(PasswordPolicy.hasUppercase("pass123!")).isFalse();
        assertThat(PasswordPolicy.hasUppercase("Pass123!")).isTrue();

        assertThat(PasswordPolicy.hasLowercase("PASS123!")).isFalse();
        assertThat(PasswordPolicy.hasLowercase("Pass123!")).isTrue();

        assertThat(PasswordPolicy.hasDigit("Password!")).isFalse();
        assertThat(PasswordPolicy.hasDigit("Password123!")).isTrue();

        assertThat(PasswordPolicy.hasSpecial("Password123")).isFalse();
        assertThat(PasswordPolicy.hasSpecial("Password123!")).isTrue();
        assertThat(PasswordPolicy.hasSpecial("Password123@")).isTrue();
        assertThat(PasswordPolicy.hasSpecial("Password123#")).isTrue();
        assertThat(PasswordPolicy.hasSpecial("Password123$")).isTrue();
        assertThat(PasswordPolicy.hasSpecial("Password123%")).isTrue();
        assertThat(PasswordPolicy.hasSpecial("Password123^")).isTrue();
        assertThat(PasswordPolicy.hasSpecial("Password123&")).isTrue();
        assertThat(PasswordPolicy.hasSpecial("Password123*")).isTrue();

        assertThat(PasswordPolicy.isValid("Password123!")).isTrue();
        assertThat(PasswordPolicy.isValid("short1!")).isFalse();
        assertThat(PasswordPolicy.isValid("password123!")).isFalse();
        assertThat(PasswordPolicy.isValid("PASSWORD123!")).isFalse();
        assertThat(PasswordPolicy.isValid("Password!!!!")).isFalse();
        assertThat(PasswordPolicy.isValid("Password1234")).isFalse();

        assertThatThrownBy(() -> PasswordPolicy.validate("weak"))
                .isInstanceOf(Exception.class);
    }

    @Test
    @DisplayName("Admin reset password succeeds when all 5 requirements are satisfied")
    void testAdminResetPasswordSuccess() throws Exception {
        ResetPasswordRequest req = new ResetPasswordRequest(adminToken, "NewValidPass123!");

        mockMvc.perform(post("/api/v1/admin/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(req)))
                .andExpect(status().isOk());

        UserAccount refreshed = users.findById(adminUser.getId()).orElseThrow();
        assertThat(passwordEncoder.matches("NewValidPass123!", refreshed.getPasswordHash())).isTrue();
    }

    @Test
    @DisplayName("Admin reset rejects password missing uppercase")
    void testAdminResetRejectsMissingUppercase() throws Exception {
        ResetPasswordRequest req = new ResetPasswordRequest(adminToken, "newvalidpass123!");

        mockMvc.perform(post("/api/v1/admin/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(req)))
                .andExpect(status().is4xxClientError());
    }

    @Test
    @DisplayName("Admin reset rejects password missing lowercase")
    void testAdminResetRejectsMissingLowercase() throws Exception {
        ResetPasswordRequest req = new ResetPasswordRequest(adminToken, "NEWVALIDPASS123!");

        mockMvc.perform(post("/api/v1/admin/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(req)))
                .andExpect(status().is4xxClientError());
    }

    @Test
    @DisplayName("Admin reset rejects password missing digit")
    void testAdminResetRejectsMissingDigit() throws Exception {
        ResetPasswordRequest req = new ResetPasswordRequest(adminToken, "NewValidPass!!!!");

        mockMvc.perform(post("/api/v1/admin/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(req)))
                .andExpect(status().is4xxClientError());
    }

    @Test
    @DisplayName("Admin reset rejects password missing special character")
    void testAdminResetRejectsMissingSpecialChar() throws Exception {
        ResetPasswordRequest req = new ResetPasswordRequest(adminToken, "NewValidPass1234");

        mockMvc.perform(post("/api/v1/admin/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(req)))
                .andExpect(status().is4xxClientError());
    }

    @Test
    @DisplayName("Admin reset rejects password shorter than 8 characters")
    void testAdminResetRejectsShorterThan8Chars() throws Exception {
        ResetPasswordRequest req = new ResetPasswordRequest(adminToken, "Pass1!");

        mockMvc.perform(post("/api/v1/admin/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(req)))
                .andExpect(status().is4xxClientError());
    }

    @Test
    @DisplayName("Public /api/auth/reset-password endpoint enforces the same requirements")
    void testPublicResetPasswordEndpoint() throws Exception {
        // Valid password succeeds
        mockMvc.perform(post("/api/auth/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(Map.of("token", adminToken, "password", "SuperSecret123$"))))
                .andExpect(status().isOk());

        // Create token for second test
        String token2 = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-2";
        resets.save(new ResetToken(token2, adminUser, Instant.now().plusSeconds(900)));

        // Missing special char fails
        mockMvc.perform(post("/api/auth/reset-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(om.writeValueAsString(Map.of("token", token2, "password", "SuperSecret1234"))))
                .andExpect(status().is4xxClientError());
    }
}
