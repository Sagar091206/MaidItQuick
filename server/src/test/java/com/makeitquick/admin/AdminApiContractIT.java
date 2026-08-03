package com.makeitquick.admin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.makeitquick.MakeItQuickApplication;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

/**
 * Contract tests that lock the admin API surface behaviour. They must keep
 * passing after the mobile backend (server/) and admin backend are merged into
 * a single process (Phase 1), so they pin down status codes, the response
 * envelope and the auth flow rather than implementation details.
 */
@SpringBootTest(classes = MakeItQuickApplication.class, properties = {
        "spring.datasource.url=jdbc:h2:mem:admincontract;MODE=MySQL;DB_CLOSE_DELAY=-1;DATABASE_TO_LOWER=TRUE",
        "spring.datasource.driver-class-name=org.h2.Driver",
        "spring.datasource.username=sa",
        "spring.datasource.password=",
        "spring.jpa.hibernate.ddl-auto=create-drop",
        "spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.H2Dialect",
        "app.bootstrap.email=contract-admin@maiditquick.com",
        "app.bootstrap.password=ContractPass-2026!",
        "app.bootstrap.support-email=contract-support@maiditquick.com",
        "app.bootstrap.support-password=ContractPass-2026!",
        "app.uploads-dir=target/test-admin-uploads",
        "app.mail.reset-url=http://localhost:5173"
})
@AutoConfigureMockMvc
class AdminApiContractIT {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void healthIsPublic() throws Exception {
        expect(mockMvc.perform(get("/actuator/health")), 200);
    }

    @Test
    void protectedEndpointRejectsAnonymous() throws Exception {
        expect(mockMvc.perform(get("/api/v1/admin/dashboard/summary")), 401);
    }

    @Test
    void loginReturnsTokenPairAndProfile() throws Exception {
        JsonNode body = expect(mockMvc.perform(post("/api/v1/admin/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                        {"email":"contract-admin@maiditquick.com","password":"ContractPass-2026!"}""")), 200);
        assertThat(body.get("accessToken").asText()).isNotBlank();
        assertThat(body.get("refreshToken").asText()).isNotBlank();
        assertThat(body.get("expiresIn").asLong()).isGreaterThan(0);
        assertThat(body.get("permissions").isArray()).isTrue();
        assertThat(body.get("admin").get("email").asText()).isEqualTo("contract-admin@maiditquick.com");
    }

    @Test
    void loginWithBadCredentialsIs401() throws Exception {
        expect(mockMvc.perform(post("/api/v1/admin/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                        {"email":"contract-admin@maiditquick.com","password":"wrong-password"}""")), 401);
    }

    @Test
    void authenticatedAdminReadsDashboardThroughEnvelope() throws Exception {
        String token = login();
        JsonNode body = expect(mockMvc.perform(get("/api/v1/admin/dashboard/summary")
                .header("Authorization", "Bearer " + token)), 200);
        assertThat(body.get("success").asBoolean()).isTrue();
        assertThat(body.has("data")).isTrue();
        assertThat(body.get("data").isObject()).isTrue();
    }

    @Test
    void authenticatedAdminListsCustomers() throws Exception {
        String token = login();
        JsonNode body = expect(mockMvc.perform(get("/api/v1/admin/customers")
                .param("page", "0")
                .param("size", "10")
                .header("Authorization", "Bearer " + token)), 200);
        assertThat(body.get("success").asBoolean()).isTrue();
        assertThat(body.get("data").has("items")).isTrue();
        assertThat(body.get("data").has("total")).isTrue();
    }

    private String login() throws Exception {
        JsonNode body = expect(mockMvc.perform(post("/api/v1/admin/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                        {"email":"contract-admin@maiditquick.com","password":"ContractPass-2026!"}""")), 200);
        return body.get("accessToken").asText();
    }

    private JsonNode expect(ResultActions actions, int expectedStatus) throws Exception {
        return objectMapper.readTree(actions
                .andExpect(status().is(expectedStatus))
                .andReturn()
                .getResponse()
                .getContentAsString());
    }
}
