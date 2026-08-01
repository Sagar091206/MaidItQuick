package com.maiditquick.admin.services;

import com.maiditquick.admin.categories.Category;
import jakarta.persistence.*;
import lombok.*;
import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "services")
@Getter
@Setter
@NoArgsConstructor
public class ServiceOffering {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;
  @Column(nullable = false)
  private String name;
  @Column(length = 1000)
  private String description;
  @ManyToOne(fetch = FetchType.EAGER)
  @JoinColumn(name = "category_id")
  private Category category;
  @Column(nullable = false)
  private BigDecimal price = BigDecimal.ZERO;
  @Column(name = "duration_minutes")
  private Integer durationMinutes;
  @Column(nullable = false)
  private boolean active = true;
  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt = Instant.now();
}
