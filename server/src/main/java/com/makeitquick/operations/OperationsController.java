package com.makeitquick.operations;

import com.makeitquick.security.Role;
import com.makeitquick.security.SessionResolver;
import com.makeitquick.security.UserAccount;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

/**
 * Admin-only controls for MakeItQuick's launch operations.
 * Authentication accepts the legacy opaque session tokens and the JWT issued by /api/v1/auth.
 */
@RestController
@RequestMapping("/api/operations")
@CrossOrigin(origins = "*")
public class OperationsController {
    private final ServiceAreaRepository areas;
    private final SlaAlertRepository alerts;
    private final RefundRequestRepository refunds;
    private final SessionResolver resolver;

    OperationsController(
            ServiceAreaRepository areas,
            SlaAlertRepository alerts,
            RefundRequestRepository refunds,
            SessionResolver resolver) {
        this.areas = areas;
        this.alerts = alerts;
        this.refunds = refunds;
        this.resolver = resolver;
    }

    @GetMapping("/areas")
    public List<ServiceArea> listAreas(@RequestHeader(value = "Authorization", required = false) String authorization) {
        requireAdmin(authorization);
        return areas.findAll();
    }

    @PostMapping("/areas")
    public ServiceArea addArea(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @Valid @RequestBody AreaInput input) {
        requireAdmin(authorization);
        if (areas.findByPinCode(input.pinCode()).isPresent()) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "This PIN code already exists");
        }
        return areas.save(new ServiceArea(input.pinCode(), input.locality().trim()));
    }

    @PostMapping("/areas/{id}/enabled")
    public ServiceArea setAreaEnabled(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @PathVariable Long id,
            @RequestBody EnabledInput input) {
        requireAdmin(authorization);
        ServiceArea area = getArea(id);
        area.setEnabled(input.enabled());
        return areas.save(area);
    }

    @GetMapping("/alerts")
    public List<SlaAlert> listAlerts(@RequestHeader(value = "Authorization", required = false) String authorization) {
        requireAdmin(authorization);
        return alerts.findAll();
    }

    @PostMapping("/alerts/{id}/resolve")
    public SlaAlert resolveAlert(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @PathVariable Long id) {
        requireAdmin(authorization);
        SlaAlert alert = alerts.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "SLA alert not found"));
        alert.resolve();
        return alerts.save(alert);
    }

    @GetMapping("/refunds")
    public List<RefundRequest> listRefunds(@RequestHeader(value = "Authorization", required = false) String authorization) {
        requireAdmin(authorization);
        return refunds.findAll();
    }

    @PostMapping("/refunds/{id}/approve")
    public RefundRequest approveRefund(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @PathVariable Long id) {
        requireAdmin(authorization);
        RefundRequest refund = getRefund(id);
        if (refund.getStatus() != RefundStatus.REQUESTED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Only requested refunds can be approved");
        }
        refund.approve();
        return refunds.save(refund);
    }

    @PostMapping("/refunds/{id}/reject")
    public RefundRequest rejectRefund(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @PathVariable Long id) {
        requireAdmin(authorization);
        RefundRequest refund = getRefund(id);
        if (refund.getStatus() != RefundStatus.REQUESTED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Only requested refunds can be rejected");
        }
        refund.reject();
        return refunds.save(refund);
    }

    @PostMapping("/refunds/{id}/complete")
    public RefundRequest completeRefund(
            @RequestHeader(value = "Authorization", required = false) String authorization,
            @PathVariable Long id) {
        requireAdmin(authorization);
        RefundRequest refund = getRefund(id);
        if (refund.getStatus() != RefundStatus.APPROVED) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Only approved refunds can be completed");
        }
        refund.complete();
        return refunds.save(refund);
    }

    private UserAccount requireAdmin(String authorization) {
        UserAccount user = resolver.fromBearer(authorization)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Please sign in"));
        if (user.getRole() != Role.ADMIN) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Admin access required");
        }
        return user;
    }

    private ServiceArea getArea(Long id) {
        return areas.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Service area not found"));
    }

    private RefundRequest getRefund(Long id) {
        return refunds.findById(id)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Refund request not found"));
    }

    record AreaInput(
            @Pattern(regexp = "\\d{6}", message = "PIN code must have six digits") String pinCode,
            @NotBlank String locality) {
    }

    record EnabledInput(boolean enabled) {
    }
}
