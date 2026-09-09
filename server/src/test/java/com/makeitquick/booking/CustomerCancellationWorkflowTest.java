package com.makeitquick.booking;

import com.makeitquick.admin.returns.ReturnRepository;
import com.makeitquick.admin.returns.ReturnRequest;
import com.makeitquick.catalog.ServiceCatalogService;
import com.makeitquick.notification.NotificationService;
import com.makeitquick.operations.RefundNotificationService;
import com.makeitquick.operations.RefundRulesEngine;
import com.makeitquick.operations.ServiceAreaService;
import com.makeitquick.payment.PaymentStatus;
import com.makeitquick.security.Role;
import com.makeitquick.security.SessionResolver;
import com.makeitquick.security.UserAccount;
import com.makeitquick.security.UserRepository;
import com.makeitquick.worker.WorkerSafetyService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.server.ResponseStatusException;

import java.math.BigDecimal;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

public class CustomerCancellationWorkflowTest {

    private BookingRepository repo;
    private BookingServiceRepository bookingServices;
    private BookingEventRepository events;
    private SessionResolver resolver;
    private UserRepository users;
    private NotificationService notifications;
    private WorkerSafetyService workerSafety;
    private ReturnRepository returns;
    private ServiceAreaService areas;
    private ServiceCatalogService catalog;
    private BookingAssignmentService assigner;
    private BookingPricingService pricing;
    private CommissionService commissions;
    private PasswordEncoder encoder;
    private RefundRulesEngine refundRulesEngine;
    private RefundNotificationService refundNotifications;

    private BookingController controller;

    private UserAccount customer;
    private UserAccount partner;
    private UserAccount otherCustomer;

    @BeforeEach
    void setUp() {
        repo = mock(BookingRepository.class);
        bookingServices = mock(BookingServiceRepository.class);
        events = mock(BookingEventRepository.class);
        resolver = mock(SessionResolver.class);
        users = mock(UserRepository.class);
        notifications = mock(NotificationService.class);
        workerSafety = mock(WorkerSafetyService.class);
        returns = mock(ReturnRepository.class);
        areas = mock(ServiceAreaService.class);
        catalog = mock(ServiceCatalogService.class);
        assigner = mock(BookingAssignmentService.class);
        pricing = mock(BookingPricingService.class);
        commissions = mock(CommissionService.class);
        encoder = mock(PasswordEncoder.class);
        refundRulesEngine = mock(RefundRulesEngine.class);
        refundNotifications = mock(RefundNotificationService.class);

        controller = new BookingController(
                repo, bookingServices, events, resolver, users, notifications,
                workerSafety, returns, areas, catalog, assigner, pricing,
                commissions, encoder, refundRulesEngine, refundNotifications, false
        );

        customer = new UserAccount("Alice Customer", "alice@example.com", "pass", Role.CUSTOMER);
        ReflectionTestUtils.setField(customer, "id", 10L);

        partner = new UserAccount("Bob Partner", "bob@example.com", "pass", Role.WORKER);
        ReflectionTestUtils.setField(partner, "id", 20L);

        otherCustomer = new UserAccount("Charlie Random", "charlie@example.com", "pass", Role.CUSTOMER);
        ReflectionTestUtils.setField(otherCustomer, "id", 30L);

        when(resolver.fromBearer("Bearer cust-token")).thenReturn(Optional.of(customer));
        when(resolver.fromBearer("Bearer partner-token")).thenReturn(Optional.of(partner));
        when(resolver.fromBearer("Bearer stranger-token")).thenReturn(Optional.of(otherCustomer));

        when(commissions.split(anyInt())).thenReturn(new CommissionService.Split(BigDecimal.valueOf(18), 1800, 8200));
        when(repo.save(any(Booking.class))).thenAnswer(inv -> inv.getArgument(0));
        when(returns.save(any(ReturnRequest.class))).thenAnswer(inv -> inv.getArgument(0));
    }

    private Booking createBooking(BookingStatus status, boolean paid, int amountPaise) {
        Booking b = new Booking(customer, "Home Cleaning", "123 Main St", "2026-09-10T10:00:00",
                "700001", 60, "Standard", null, 0, null);
        ReflectionTestUtils.setField(b, "id", 101L);
        b.setStatus(status);
        if (paid) {
            b.markPaid("UPI", amountPaise);
        } else {
            b.setPaymentAmountPaise(amountPaise);
        }
        if (status != BookingStatus.REQUESTED) {
            b.setWorker(partner);
        }
        return b;
    }

    @Test
    void testCustomerCanCancelInRequestedStage() {
        Booking b = createBooking(BookingStatus.REQUESTED, false, 10000);
        when(repo.findById(101L)).thenReturn(Optional.of(b));

        var view = controller.cancel("Bearer cust-token", 101L,
                new BookingController.Reason("Booked by mistake / duplicate booking", "Booked twice"));

        assertEquals(BookingStatus.CANCELLED, view.get("status"));
        assertEquals("BEFORE_ASSIGNMENT", view.get("cancellationStage"));
        assertEquals("CUSTOMER", view.get("cancelledBy"));
        assertEquals("Booked by mistake / duplicate booking", view.get("cancellationReason"));
        assertEquals("Booked twice", view.get("cancellationDetails"));

        // Since unpaid, no refund request should be auto-created
        verify(returns, never()).save(any(ReturnRequest.class));
    }

    @Test
    void testCustomerCanCancelInstantMaidInSearchingStage() {
        Booking b = createBooking(BookingStatus.SEARCHING, true, 35282);
        when(repo.findById(101L)).thenReturn(Optional.of(b));
        when(returns.findTopByBookingIdOrderByCreatedAtDesc(101L)).thenReturn(Optional.empty());

        RefundRulesEngine.RefundRecommendation recommendation = new RefundRulesEngine.RefundRecommendation(
                RefundRulesEngine.CUSTOMER_FAULT, "minor", RefundRulesEngine.RESOLUTION_FULL_REFUND,
                100, 35282, false, "Customer cancelled before partner assignment. 100% full refund recommended."
        );
        when(refundRulesEngine.evaluate(anyString(), eq(b), eq(35282), anyInt(), anyString(), isNull(), eq("BEFORE_ASSIGNMENT")))
                .thenReturn(recommendation);

        var view = controller.cancel("Bearer cust-token", 101L,
                new BookingController.Reason("Plans changed / service no longer required", "Cancel instant maid"));

        assertEquals(BookingStatus.CANCELLED, view.get("status"));
        assertEquals("BEFORE_ASSIGNMENT", view.get("cancellationStage"));
        assertEquals("CUSTOMER", view.get("cancelledBy"));
        assertEquals("Plans changed / service no longer required", view.get("cancellationReason"));
        assertEquals("Cancel instant maid", view.get("cancellationDetails"));

        // Verify ReturnRequest was automatically created with BEFORE_ASSIGNMENT stage and full refund advisory
        ArgumentCaptor<ReturnRequest> refundCaptor = ArgumentCaptor.forClass(ReturnRequest.class);
        verify(returns, atLeastOnce()).save(refundCaptor.capture());
        ReturnRequest savedRefund = refundCaptor.getValue();
        assertEquals(101L, savedRefund.getBookingId());
        assertEquals("BEFORE_ASSIGNMENT", savedRefund.getCancellationStage());
        assertEquals("Plans changed / service no longer required", savedRefund.getCancellationReason());
        assertEquals(RefundRulesEngine.RESOLUTION_FULL_REFUND, savedRefund.getRecommendedResolution());
        assertEquals(100, savedRefund.getRecommendedRefundPercentage());

        // Verify admin email notification was triggered
        verify(refundNotifications, times(1)).notifyAdminOnRefundCreated(any(), eq(b), eq(customer));
    }

    @Test
    void testCustomerCanCancelInAcceptedStageWithPaidBooking_TriggersAutoRefund() {
        Booking b = createBooking(BookingStatus.ACCEPTED, true, 15000);
        when(repo.findById(101L)).thenReturn(Optional.of(b));
        when(returns.findTopByBookingIdOrderByCreatedAtDesc(101L)).thenReturn(Optional.empty());

        RefundRulesEngine.RefundRecommendation recommendation = new RefundRulesEngine.RefundRecommendation(
                RefundRulesEngine.CUSTOMER_FAULT, "minor", RefundRulesEngine.RESOLUTION_FULL_REFUND,
                100, 15000, false, "Customer cancelled before arrival"
        );
        when(refundRulesEngine.evaluate(anyString(), eq(b), eq(15000), anyInt(), anyString(), isNull(), eq("AFTER_ASSIGNMENT")))
                .thenReturn(recommendation);

        var view = controller.cancel("Bearer cust-token", 101L,
                new BookingController.Reason("Plans changed / service no longer required", "Guest arrived"));

        assertEquals(BookingStatus.CANCELLED, view.get("status"));
        assertEquals("AFTER_ASSIGNMENT", view.get("cancellationStage"));
        assertEquals("CUSTOMER", view.get("cancelledBy"));

        // Verify ReturnRequest was automatically created and evaluated
        ArgumentCaptor<ReturnRequest> refundCaptor = ArgumentCaptor.forClass(ReturnRequest.class);
        verify(returns, atLeastOnce()).save(refundCaptor.capture());
        ReturnRequest savedRefund = refundCaptor.getValue();
        assertEquals(101L, savedRefund.getBookingId());
        assertEquals("AFTER_ASSIGNMENT", savedRefund.getCancellationStage());
        assertEquals("Plans changed / service no longer required", savedRefund.getCancellationReason());
        assertEquals(RefundRulesEngine.RESOLUTION_FULL_REFUND, savedRefund.getRecommendedResolution());
        assertEquals(100, savedRefund.getRecommendedRefundPercentage());

        // Verify admin email notification was triggered
        verify(refundNotifications, times(1)).notifyAdminOnRefundCreated(any(), eq(b), eq(customer));
    }

    @Test
    void testCustomerCanCancelInOnTheWayAndArrivedAndInProgressStages() {
        for (BookingStatus activeStatus : new BookingStatus[]{BookingStatus.ON_THE_WAY, BookingStatus.ARRIVED, BookingStatus.IN_PROGRESS}) {
            Booking b = createBooking(activeStatus, false, 12000);
            when(repo.findById(101L)).thenReturn(Optional.of(b));

            var view = controller.cancel("Bearer cust-token", 101L,
                    new BookingController.Reason("Emergency / unexpected situation", "Medical reason"));

            assertEquals(BookingStatus.CANCELLED, view.get("status"));
            assertNotNull(view.get("cancellationStage"));
            assertEquals("CUSTOMER", view.get("cancelledBy"));
        }
    }

    @Test
    void testCustomerCannotCancelCompletedOrCancelledBooking() {
        Booking completed = createBooking(BookingStatus.COMPLETED, true, 10000);
        when(repo.findById(101L)).thenReturn(Optional.of(completed));

        ResponseStatusException ex = assertThrows(ResponseStatusException.class, () ->
                controller.cancel("Bearer cust-token", 101L,
                        new BookingController.Reason("test", null)));
        assertEquals(HttpStatus.CONFLICT, ex.getStatusCode());

        Booking cancelled = createBooking(BookingStatus.CANCELLED, true, 10000);
        when(repo.findById(102L)).thenReturn(Optional.of(cancelled));

        ResponseStatusException ex2 = assertThrows(ResponseStatusException.class, () ->
                controller.cancel("Bearer cust-token", 102L,
                        new BookingController.Reason("test", null)));
        assertEquals(HttpStatus.CONFLICT, ex2.getStatusCode());
    }

    @Test
    void testUnauthorizedUserCannotCancelBooking() {
        Booking b = createBooking(BookingStatus.REQUESTED, false, 10000);
        when(repo.findById(101L)).thenReturn(Optional.of(b));

        ResponseStatusException ex = assertThrows(ResponseStatusException.class, () ->
                controller.cancel("Bearer stranger-token", 101L,
                        new BookingController.Reason("test", null)));
        assertEquals(HttpStatus.FORBIDDEN, ex.getStatusCode());
    }

    @Test
    void testPartnerCannotCancelWhenWorkerIsOnTheWay() {
        Booking b = createBooking(BookingStatus.ON_THE_WAY, true, 10000);
        when(repo.findById(101L)).thenReturn(Optional.of(b));

        // Partner can only cancel ASSIGNED or ACCEPTED
        ResponseStatusException ex = assertThrows(ResponseStatusException.class, () ->
                controller.cancel("Bearer partner-token", 101L,
                        new BookingController.Reason("partner cannot come", null)));
        assertEquals(HttpStatus.CONFLICT, ex.getStatusCode());
    }
}
