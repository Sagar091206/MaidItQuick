package com.makeitquick.support;

import com.makeitquick.notification.NotificationService;
import com.makeitquick.notification.NotificationType;
import com.makeitquick.security.Role;
import com.makeitquick.security.SessionResolver;
import com.makeitquick.security.UserAccount;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class CustomerSupportControllerTest {

    private SupportTicketRepository tickets;
    private SupportMessageRepository messages;
    private SessionResolver resolver;
    private NotificationService notifications;

    private SupportController controller;

    private UserAccount customer;
    private UserAccount partner;
    private UserAccount otherCustomer;
    private UserAccount admin;

    @BeforeEach
    void setUp() {
        tickets = mock(SupportTicketRepository.class);
        messages = mock(SupportMessageRepository.class);
        resolver = mock(SessionResolver.class);
        notifications = mock(NotificationService.class);

        controller = new SupportController(tickets, messages, resolver, notifications);

        customer = new UserAccount("Customer One", "9876543210", "pass", Role.CUSTOMER);
        ReflectionTestUtils.setField(customer, "id", 101L);

        partner = new UserAccount("Partner Pro", "9876543211", "pass", Role.WORKER);
        ReflectionTestUtils.setField(partner, "id", 202L);

        otherCustomer = new UserAccount("Customer Two", "9876543212", "pass", Role.CUSTOMER);
        ReflectionTestUtils.setField(otherCustomer, "id", 303L);

        admin = new UserAccount("Super Admin", "9876543213", "pass", Role.ADMIN);
        ReflectionTestUtils.setField(admin, "id", 1L);
    }

    @Test
    void customerCreatesTicketWithCategoryAndBooking() {
        when(resolver.fromBearer("Bearer cust-token")).thenReturn(Optional.of(customer));
        when(tickets.save(any(SupportTicket.class))).thenAnswer(inv -> {
            SupportTicket saved = inv.getArgument(0);
            ReflectionTestUtils.setField(saved, "id", 1L);
            ReflectionTestUtils.setField(saved, "createdAt", Instant.now());
            return saved;
        });

        SupportController.TicketInput input = new SupportController.TicketInput(
                "Payment deducted twice",
                "I was charged ₹350 two times for booking #55",
                "PAYMENT",
                55L
        );

        Map<String, Object> res = controller.create("Bearer cust-token", input);

        assertNotNull(res.get("id"));
        assertEquals("Payment deducted twice", res.get("subject"));
        assertEquals("I was charged ₹350 two times for booking #55", res.get("message"));
        assertEquals("PAYMENT", res.get("category"));
        assertEquals(55L, res.get("bookingId"));
        assertEquals("Customer One", res.get("requester"));
        assertEquals(Role.CUSTOMER, res.get("requesterRole"));
        assertEquals(TicketStatus.OPEN, res.get("status"));

        ArgumentCaptor<SupportTicket> captor = ArgumentCaptor.forClass(SupportTicket.class);
        verify(tickets).save(captor.capture());
        assertEquals("PAYMENT", captor.getValue().getCategory());
        assertEquals(55L, captor.getValue().getBookingId());
        assertEquals(customer, captor.getValue().getRequester());
    }

    @Test
    void customerFetchesOnlyTheirOwnTickets() {
        when(resolver.fromBearer("Bearer cust-token")).thenReturn(Optional.of(customer));

        SupportTicket custTicket = new SupportTicket(customer, "App issue", "Cannot login", "ACCOUNT", null);
        ReflectionTestUtils.setField(custTicket, "id", 10L);
        ReflectionTestUtils.setField(custTicket, "createdAt", Instant.now());

        when(tickets.findByRequesterOrderByIdDesc(customer)).thenReturn(List.of(custTicket));

        List<Map<String, Object>> list = controller.mine("Bearer cust-token");
        assertEquals(1, list.size());
        assertEquals(10L, list.get(0).get("id"));
        assertEquals("App issue", list.get(0).get("subject"));
        assertEquals(Role.CUSTOMER, list.get(0).get("requesterRole"));
        verify(tickets).findByRequesterOrderByIdDesc(customer);
    }

    @Test
    void partnerFetchesOnlyTheirOwnTickets() {
        when(resolver.fromBearer("Bearer partner-token")).thenReturn(Optional.of(partner));

        SupportTicket partnerTicket = new SupportTicket(partner, "Payout delay", "Payout not received", "PAYMENT", null);
        ReflectionTestUtils.setField(partnerTicket, "id", 20L);
        ReflectionTestUtils.setField(partnerTicket, "createdAt", Instant.now());

        when(tickets.findByRequesterOrderByIdDesc(partner)).thenReturn(List.of(partnerTicket));

        List<Map<String, Object>> list = controller.mine("Bearer partner-token");
        assertEquals(1, list.size());
        assertEquals(20L, list.get(0).get("id"));
        assertEquals("Payout delay", list.get(0).get("subject"));
        assertEquals(Role.WORKER, list.get(0).get("requesterRole"));
        verify(tickets).findByRequesterOrderByIdDesc(partner);
    }

    @Test
    void conversationUnauthorizedUserForbidden() {
        when(resolver.fromBearer("Bearer other-token")).thenReturn(Optional.of(otherCustomer));

        SupportTicket custTicket = new SupportTicket(customer, "Booking issue", "Late arrival", "BOOKING", 12L);
        ReflectionTestUtils.setField(custTicket, "id", 50L);
        when(tickets.findById(50L)).thenReturn(Optional.of(custTicket));

        ResponseStatusException ex1 = assertThrows(ResponseStatusException.class,
                () -> controller.conversation("Bearer other-token", 50L));
        assertEquals(HttpStatus.FORBIDDEN, ex1.getStatusCode());

        ResponseStatusException ex2 = assertThrows(ResponseStatusException.class,
                () -> controller.sendMessage("Bearer other-token", 50L, new SupportController.ReplyInput("intruder message")));
        assertEquals(HttpStatus.FORBIDDEN, ex2.getStatusCode());
    }

    @Test
    void customerCanSendMessageInTicketConversation() {
        when(resolver.fromBearer("Bearer cust-token")).thenReturn(Optional.of(customer));

        SupportTicket custTicket = new SupportTicket(customer, "Booking issue", "Late arrival", "BOOKING", 12L);
        ReflectionTestUtils.setField(custTicket, "id", 50L);
        when(tickets.findById(50L)).thenReturn(Optional.of(custTicket));
        when(messages.save(any(SupportMessage.class))).thenAnswer(inv -> {
            SupportMessage msg = inv.getArgument(0);
            ReflectionTestUtils.setField(msg, "id", 77L);
            ReflectionTestUtils.setField(msg, "createdAt", Instant.now());
            return msg;
        });

        Map<String, Object> sent = controller.sendMessage("Bearer cust-token", 50L,
                new SupportController.ReplyInput("Any update on this?"));

        assertEquals(77L, sent.get("id"));
        assertEquals(Role.CUSTOMER, sent.get("senderRole"));
        assertEquals("Any update on this?", sent.get("message"));

        assertEquals(TicketStatus.IN_PROGRESS, custTicket.getStatus());
        verify(tickets).save(custTicket);
    }

    @Test
    void adminCanReplyToTicket() {
        when(resolver.fromBearer("Bearer admin-token")).thenReturn(Optional.of(admin));

        SupportTicket custTicket = new SupportTicket(customer, "Refund status", "When will I get refund?", "REFUND", 12L);
        ReflectionTestUtils.setField(custTicket, "id", 80L);
        when(tickets.findById(80L)).thenReturn(Optional.of(custTicket));
        when(tickets.save(any(SupportTicket.class))).thenAnswer(inv -> inv.getArgument(0));

        Map<String, Object> reply = controller.reply("Bearer admin-token", 80L,
                new SupportController.ReplyInput("Your refund has been initiated and will credit in 2-3 days."));

        assertEquals("Your refund has been initiated and will credit in 2-3 days.", reply.get("reply"));
        assertEquals(TicketStatus.IN_PROGRESS, custTicket.getStatus());
        verify(notifications).send(eq(customer), eq(NotificationType.OPERATIONS), eq("Support replied"), contains("refund has been initiated"));
    }

    @Test
    void scenariosReturnsAll18Rules() {
        List<SupportRulesEngine.ScenarioRule> rules = controller.scenarios();
        assertEquals(18, rules.size());
        assertTrue(rules.stream().anyMatch(r -> r.scenario().equals("PROPERTY_DAMAGE") && r.requiresEvidence() && r.connectsToRefund()));
        assertTrue(rules.stream().anyMatch(r -> r.scenario().equals("SAFETY_CONCERN") && r.priority().equals("URGENT") && !r.requiresEvidence()));
        assertTrue(rules.stream().anyMatch(r -> r.scenario().equals("PARTNER_NO_SHOW") && r.connectsToRefund()));
    }

    @Test
    void scenarioRequiringEvidenceFailsWithoutEvidence() {
        when(resolver.fromBearer("Bearer cust-token")).thenReturn(Optional.of(customer));

        SupportController.TicketInput input = new SupportController.TicketInput(
                "Broken vase",
                "Cleaner knocked over my antique vase during service",
                "SAFETY",
                12L,
                "PROPERTY_DAMAGE",
                List.of()
        );

        ResponseStatusException ex = assertThrows(ResponseStatusException.class,
                () -> controller.create("Bearer cust-token", input));
        assertEquals(HttpStatus.BAD_REQUEST, ex.getStatusCode());
        assertTrue(ex.getReason().contains("Photographic evidence is required"));
    }

    @Test
    void scenarioRequiringEvidenceSucceedsWithEvidence() {
        when(resolver.fromBearer("Bearer cust-token")).thenReturn(Optional.of(customer));
        when(tickets.save(any(SupportTicket.class))).thenAnswer(inv -> {
            SupportTicket saved = inv.getArgument(0);
            ReflectionTestUtils.setField(saved, "id", 99L);
            ReflectionTestUtils.setField(saved, "createdAt", Instant.now());
            return saved;
        });

        SupportController.TicketInput input = new SupportController.TicketInput(
                "Broken vase",
                "Cleaner knocked over my antique vase during service",
                null,
                12L,
                "PROPERTY_DAMAGE",
                List.of("/uploads/support/evidence-1.jpg", "/uploads/support/evidence-2.jpg")
        );

        Map<String, Object> res = controller.create("Bearer cust-token", input);

        assertEquals(99L, res.get("id"));
        assertEquals("PROPERTY_DAMAGE", res.get("scenario"));
        assertEquals("HIGH", res.get("priority"));
        assertEquals("CRITICAL", res.get("severity"));
        assertEquals(true, res.get("requiresAdminReview"));
        assertEquals(true, res.get("connectsToRefund"));
        assertNotNull(res.get("recommendedAction"));
        @SuppressWarnings("unchecked")
        List<String> list = (List<String>) res.get("evidenceList");
        assertEquals(2, list.size());
        assertEquals("/uploads/support/evidence-1.jpg", list.get(0));
    }
}
