package com.maiditquick.admin.settlements;

import com.maiditquick.admin.audit.AuditService;
import com.maiditquick.admin.bookings.Booking;
import com.maiditquick.admin.bookings.BookingRepository;
import com.maiditquick.admin.common.ApiResponse;
import com.maiditquick.admin.common.NotFoundException;
import com.maiditquick.admin.notifications.Notification;
import com.maiditquick.admin.notifications.NotificationRepository;
import com.maiditquick.admin.partners.Partner;
import com.maiditquick.admin.partners.PartnerRepository;
import com.maiditquick.admin.settings.Setting;
import com.maiditquick.admin.settings.SettingRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import org.springframework.data.domain.Sort;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.WeekFields;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/admin/settlements")
public class SettlementController {

  private final PayoutRecordRepository payouts;
  private final BookingRepository bookings;
  private final PartnerRepository partners;
  private final SettingRepository settings;
  private final NotificationRepository notifications;
  private final AuditService audit;

  public SettlementController(PayoutRecordRepository payouts, BookingRepository bookings,
                              PartnerRepository partners, SettingRepository settings,
                              NotificationRepository notifications, AuditService audit) {
    this.payouts = payouts;
    this.bookings = bookings;
    this.partners = partners;
    this.settings = settings;
    this.notifications = notifications;
    this.audit = audit;
  }

  /* ---------- Payout queue ---------- */

  @GetMapping("/queue")
  @PreAuthorize("hasAuthority('SETTLEMENTS_READ')")
  public ApiResponse<List<PayoutRecord>> queue(
      @RequestParam(defaultValue = "") String status) {
    List<PayoutRecord> all = ensureCurrentWeekQueue();
    if (status.isBlank()) {
      return ApiResponse.ok(all);
    }
    String st = status.trim().toUpperCase(Locale.ROOT);
    return ApiResponse.ok(all.stream().filter(p -> st.equals(p.getStatus())).toList());
  }

  @PostMapping("/{id}/pay")
  @PreAuthorize("hasAuthority('SETTLEMENTS_WRITE')")
  public ApiResponse<PayoutRecord> pay(@PathVariable long id, HttpServletRequest req) {
    PayoutRecord rec = find(id);
    if ("PAID".equals(rec.getStatus())) {
      throw new IllegalArgumentException("This payout has already been initiated");
    }
    PayoutRecord saved = payOne(rec, req);
    return ApiResponse.ok("Payout initiated", saved);
  }

  @PostMapping("/bulk-pay")
  @PreAuthorize("hasAuthority('SETTLEMENTS_WRITE')")
  public ApiResponse<List<PayoutRecord>> bulkPay(@Valid @RequestBody BulkPay body,
                                                 HttpServletRequest req) {
    List<PayoutRecord> paid = new ArrayList<>();
    for (Long id : body.ids()) {
      PayoutRecord rec = find(id);
      if (!"PAID".equals(rec.getStatus())) {
        paid.add(payOne(rec, req));
      }
    }
    return ApiResponse.ok("Bulk payouts initiated", paid);
  }

  @DeleteMapping("/{id}")
  @PreAuthorize("hasAuthority('SETTLEMENTS_WRITE')")
  public ApiResponse<Void> remove(@PathVariable long id, HttpServletRequest req) {
    PayoutRecord rec = find(id);
    String before = rec.getStatus();
    payouts.delete(rec);
    audit.record("SETTLEMENT_REMOVED", "SETTLEMENTS", String.valueOf(id),
        "{\"status\":\"" + before + "\"}", null, req);
    return ApiResponse.ok("Queued payout removed");
  }

  /* ---------- Commission rate configurator ---------- */

  @GetMapping("/commission")
  @PreAuthorize("hasAuthority('SETTLEMENTS_READ')")
  public ApiResponse<BigDecimal> commission() {
    return ApiResponse.ok(commissionPct());
  }

  @PutMapping("/commission")
  @PreAuthorize("hasAuthority('SETTLEMENTS_WRITE')")
  public ApiResponse<BigDecimal> setCommission(@Valid @RequestBody CommissionInput input,
                                               HttpServletRequest req) {
    if (input.commissionPct().compareTo(BigDecimal.ONE) < 0
        || input.commissionPct().compareTo(BigDecimal.valueOf(100)) > 0) {
      throw new IllegalArgumentException("Commission rate must be between 1 and 100 percent");
    }
    Setting s = settings.findBySettingKey("platform_commission_pct")
        .orElseGet(() -> {
          Setting created = new Setting();
          created.setSettingKey("platform_commission_pct");
          created.setDescription("Platform commission percentage applied to every booking payout");
          return created;
        });
    String before = s.getSettingValue();
    s.setSettingValue(input.commissionPct().toPlainString());
    settings.save(s);
    audit.record("COMMISSION_RATE_CHANGED", "SETTLEMENTS", s.getId() == null
            ? "platform_commission_pct" : String.valueOf(s.getId()),
        "{\"commissionPct\":" + before + "}",
        "{\"commissionPct\":" + input.commissionPct().toPlainString() + "}", req);
    return ApiResponse.ok("Commission rate updated", input.commissionPct());
  }

  /* ---------- helpers ---------- */

  private PayoutRecord payOne(PayoutRecord rec, HttpServletRequest req) {
    rec.setStatus("PAID");
    rec.setTransactionRef("TX-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase());
    rec.setPaidAt(Instant.now());
    rec.setPaidByAdminId(currentAdminId());
    PayoutRecord saved = payouts.save(rec);
    audit.record("SETTLEMENT_PAID", "SETTLEMENTS", String.valueOf(saved.getId()),
        "{\"status\":\"PENDING\"}",
        "{\"status\":\"PAID\",\"transactionRef\":\"" + saved.getTransactionRef()
            + "\",\"amount\":\"" + saved.getAmount().toPlainString()
            + "\",\"period\":\"" + saved.getPeriodLabel() + "\"}",
        req);
    notify("Payout initiated — " + saved.getPartner().getName(),
        "A payout of ₹" + saved.getAmount().toPlainString() + " for period "
            + saved.getPeriodLabel() + " has been initiated. Reference: " + saved.getTransactionRef(),
        "SUCCESS");
    return saved;
  }

  private List<PayoutRecord> ensureCurrentWeekQueue() {
    String period = currentPeriod();
    Instant weekStart = LocalDate.now().with(DayOfWeek.MONDAY)
        .atStartOfDay(ZoneId.systemDefault()).toInstant();
    List<Partner> approved = partners.findAll().stream()
        .filter(p -> "APPROVED".equals(p.getKycStatus())).toList();
    BigDecimal pct = commissionPct();
    for (Partner partner : approved) {
      if (payouts.findByPartnerAndPeriodLabel(partner, period).isPresent()) continue;
      BigDecimal net = BigDecimal.ZERO;
      for (Booking b : bookings.findAll()) {
        if (b.getPartner() == null || !b.getPartner().getId().equals(partner.getId())) continue;
        if (!"COMPLETED".equals(b.getStatus())) continue;
        if (b.getCreatedAt() == null || b.getCreatedAt().isBefore(weekStart)) continue;
        BigDecimal amount = b.getTotalAmount() == null ? BigDecimal.ZERO : b.getTotalAmount();
        BigDecimal commission = amount.multiply(pct)
            .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
        net = net.add(amount.subtract(commission));
      }
      if (net.compareTo(BigDecimal.ZERO) <= 0) continue;
      PayoutRecord rec = new PayoutRecord();
      rec.setPartner(partner);
      rec.setPeriodLabel(period);
      rec.setAmount(net);
      payouts.save(rec);
    }
    return payouts.findAll(Sort.by(Sort.Direction.DESC, "id"));
  }

  private String currentPeriod() {
    LocalDate now = LocalDate.now();
    int year = now.get(WeekFields.ISO.weekBasedYear());
    int week = now.get(WeekFields.ISO.weekOfWeekBasedYear());
    return year + "-W" + week;
  }

  private BigDecimal commissionPct() {
    return settings.findBySettingKey("platform_commission_pct")
        .map(s -> {
          try {
            return new BigDecimal(s.getSettingValue());
          } catch (NumberFormatException e) {
            return BigDecimal.valueOf(18);
          }
        })
        .orElse(BigDecimal.valueOf(18));
  }

  private PayoutRecord find(long id) {
    return payouts.findById(id).orElseThrow(() -> NotFoundException.of("PayoutRecord", id));
  }

  private long currentAdminId() {
    try {
      return Long.parseLong(SecurityContextHolder.getContext().getAuthentication().getName());
    } catch (Exception e) {
      return -1;
    }
  }

  private void notify(String title, String message, String type) {
    Notification n = new Notification();
    n.setTitle(title);
    n.setMessage(message);
    n.setType(type);
    notifications.save(n);
  }

  public record BulkPay(@NotEmpty List<@NotNull Long> ids) {}

  public record CommissionInput(@NotNull BigDecimal commissionPct) {}
}
