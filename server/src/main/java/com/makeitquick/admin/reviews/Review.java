package com.makeitquick.admin.reviews;

import com.makeitquick.booking.Booking;
import com.makeitquick.security.UserAccount;
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
  private UserAccount customer;
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
