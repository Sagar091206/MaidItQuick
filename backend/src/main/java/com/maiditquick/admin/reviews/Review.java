package com.maiditquick.admin.reviews;

import com.maiditquick.admin.bookings.Booking;
import com.maiditquick.admin.customers.Customer;
import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;
import java.time.Instant;

@Entity
@Table(name = "reviews")
@Getter
@Setter
@NoArgsConstructor
public class Review {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;
  @ManyToOne(fetch = FetchType.EAGER)
  @JoinColumn(name = "customer_id")
  @OnDelete(action = OnDeleteAction.SET_NULL)
  private Customer customer;
  @ManyToOne(fetch = FetchType.EAGER)
  @JoinColumn(name = "booking_id")
  @OnDelete(action = OnDeleteAction.SET_NULL)
  private Booking booking;
  @Column(nullable = false)
  private int rating;
  @Column(length = 1000)
  private String comment;
  @Column(nullable = false)
  private String status = "PENDING";
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt = Instant.now();
}
