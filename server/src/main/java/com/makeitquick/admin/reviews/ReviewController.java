package com.makeitquick.admin.reviews;

import com.makeitquick.admin.audit.AuditService;
import com.makeitquick.admin.common.ApiResponse;
import com.makeitquick.admin.common.NotFoundException;
import com.makeitquick.admin.common.PageResponse;
import com.makeitquick.booking.Booking;
import com.makeitquick.booking.BookingRepository;
import com.makeitquick.security.UserAccount;
import com.makeitquick.security.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/admin/reviews")
public class ReviewController {

  private final ReviewRepository reviews;
  private final UserRepository customers;
  private final BookingRepository bookings;
  private final AuditService audit;

  public ReviewController(ReviewRepository reviews, UserRepository customers,
                          BookingRepository bookings, AuditService audit) {
    this.reviews = reviews;
    this.customers = customers;
    this.bookings = bookings;
    this.audit = audit;
  }

  @GetMapping
  @PreAuthorize("hasAuthority('REVIEWS_READ')")
  public ApiResponse<PageResponse<Review>> list(
      @RequestParam(defaultValue = "") String status,
      @RequestParam(defaultValue = "0") @Min(0) int page,
      @RequestParam(defaultValue = "20") @Min(1) @Max(100) int size) {
    PageRequest pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "id"));
    var result = status.isBlank() ? reviews.findAll(pageable) : reviews.findByStatusIgnoreCase(status.toUpperCase(), pageable);
    return ApiResponse.ok(PageResponse.from(result));
  }

  @GetMapping("/{id}")
  @PreAuthorize("hasAuthority('REVIEWS_READ')")
  public ApiResponse<Review> get(@PathVariable long id) {
    return ApiResponse.ok(find(id));
  }

  @PostMapping
  @PreAuthorize("hasAuthority('REVIEWS_WRITE')")
  public ApiResponse<Review> create(@Valid @RequestBody Upsert body, HttpServletRequest req) {
    Review r = new Review();
    apply(r, body);
    Review saved = reviews.save(r);
    audit.record("REVIEW_CREATED", "REVIEWS", String.valueOf(saved.getId()), null,
        "{\"rating\":" + saved.getRating() + ",\"status\":\"" + saved.getStatus() + "\"}", req);
    return ApiResponse.created(saved);
  }

  @PutMapping("/{id}")
  @PreAuthorize("hasAuthority('REVIEWS_WRITE')")
  public ApiResponse<Review> update(@PathVariable long id, @Valid @RequestBody Upsert body, HttpServletRequest req) {
    Review r = find(id);
    apply(r, body);
    Review saved = reviews.save(r);
    audit.record("REVIEW_UPDATED", "REVIEWS", String.valueOf(id), null,
        "{\"rating\":" + saved.getRating() + ",\"status\":\"" + saved.getStatus() + "\"}", req);
    return ApiResponse.ok(saved);
  }

  @PatchMapping("/{id}/status")
  @PreAuthorize("hasAuthority('REVIEWS_WRITE')")
  public ApiResponse<Review> moderate(@PathVariable long id, @Valid @RequestBody Moderate input, HttpServletRequest req) {
    Review r = find(id);
    r.setStatus(input.status());
    Review saved = reviews.save(r);
    audit.record("REVIEW_MODERATED", "REVIEWS", String.valueOf(id), null,
        "{\"status\":\"" + input.status() + "\"}", req);
    return ApiResponse.ok(saved);
  }

  @DeleteMapping("/{id}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  @PreAuthorize("hasAuthority('REVIEWS_WRITE')")
  public void delete(@PathVariable long id, HttpServletRequest req) {
    reviews.delete(find(id));
    audit.record("REVIEW_DELETED", "REVIEWS", String.valueOf(id), null, null, req);
  }

  private void apply(Review r, Upsert body) {
    r.setCustomer(resolveCustomer(body.customerId()));
    r.setBooking(resolveBooking(body.bookingId()));
    r.setRating(body.rating());
    r.setComment(body.comment());
    r.setStatus(body.status() == null ? "PENDING" : body.status());
  }

  private Review find(long id) {
    return reviews.findById(id).orElseThrow(() -> NotFoundException.of("Review", id));
  }

  private UserAccount resolveCustomer(Long id) {
    if (id == null) {
      return null;
    }
    return customers.findById(id).orElseThrow(() -> NotFoundException.of("Customer", id));
  }

  private Booking resolveBooking(Long id) {
    if (id == null) {
      return null;
    }
    return bookings.findById(id).orElseThrow(() -> NotFoundException.of("Booking", id));
  }

  public record Upsert(
      Long customerId,
      Long bookingId,
      @NotNull @Min(1) @Max(5) Integer rating,
      @Size(max = 1000) String comment,
      @Pattern(regexp = "PENDING|APPROVED|REJECTED") String status) {
  }

  public record Moderate(
      @NotBlank @Pattern(regexp = "PENDING|APPROVED|REJECTED") String status) {
  }
}
