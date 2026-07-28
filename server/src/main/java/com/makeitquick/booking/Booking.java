package com.makeitquick.booking;
import com.makeitquick.security.UserAccount; import jakarta.persistence.*; import java.time.Instant;
@Entity @Table(name="bookings")
public class Booking {
 @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
 @ManyToOne(optional=false) private UserAccount customer; @ManyToOne private UserAccount worker;
 @Column(nullable=false) private String service; @Column(nullable=false) private String address; @Column(nullable=false) private String scheduledFor; private String pinCode;
 private Integer durationMinutes=60; private String optionLabel; private String promoCode; private Integer discountPaise=0;
 @Enumerated(EnumType.STRING) @Column(nullable=false) private BookingStatus status=BookingStatus.REQUESTED;
 private String cancellationReason; private String startOtpHash; private String endOtpHash; private Integer rating; private String ratingComment; @Column(nullable=false,updatable=false) private Instant createdAt=Instant.now();
 protected Booking(){} public Booking(UserAccount c,String s,String a,String t,String pin,Integer duration,String option,String promo,int discount){customer=c;service=s;address=a;scheduledFor=t;pinCode=pin;durationMinutes=duration==null?60:duration;optionLabel=option==null?"Standard":option;promoCode=promo;discountPaise=discount;}
 public Long getId(){return id;} public UserAccount getCustomer(){return customer;} public UserAccount getWorker(){return worker;} public String getService(){return service;} public String getAddress(){return address;} public String getScheduledFor(){return scheduledFor;} public String getPinCode(){return pinCode;} public Integer getDurationMinutes(){return durationMinutes;} public String getOptionLabel(){return optionLabel;} public String getPromoCode(){return promoCode;} public Integer getDiscountPaise(){return discountPaise;} public BookingStatus getStatus(){return status;} public Integer getRating(){return rating;}
 public void assign(UserAccount u){worker=u;status=BookingStatus.ASSIGNED;} public void cancel(String r){status=BookingStatus.CANCELLED;cancellationReason=r;} public void reschedule(String s){scheduledFor=s;} public void setStartOtpHash(String h){startOtpHash=h;} public String getStartOtpHash(){return startOtpHash;} public void begin(){status=BookingStatus.IN_PROGRESS;} public void setEndOtpHash(String h){endOtpHash=h;} public String getEndOtpHash(){return endOtpHash;} public void complete(){status=BookingStatus.COMPLETED;} public void rate(int r,String c){rating=r;ratingComment=c;}
 public void enRoute(){status=BookingStatus.ON_THE_WAY;}
}
