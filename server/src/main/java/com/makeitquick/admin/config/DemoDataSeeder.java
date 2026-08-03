package com.makeitquick.admin.config;

import com.makeitquick.admin.escalations.Dispute;
import com.makeitquick.admin.escalations.DisputeRepository;
import com.makeitquick.admin.partners.Partner;
import com.makeitquick.admin.partners.PartnerRepository;
import com.makeitquick.admin.returns.ReturnRequest;
import com.makeitquick.admin.returns.ReturnRepository;
import com.makeitquick.admin.settings.Setting;
import com.makeitquick.admin.settings.SettingRepository;
import com.makeitquick.admin.support.SupportRepository;
import com.makeitquick.admin.support.SupportRequest;
import com.makeitquick.booking.Booking;
import com.makeitquick.booking.BookingRepository;
import com.makeitquick.booking.BookingStatus;
import com.makeitquick.operations.AvailabilityStatus;
import com.makeitquick.payment.Payment;
import com.makeitquick.payment.PaymentRepository;
import com.makeitquick.security.Role;
import com.makeitquick.security.UserAccount;
import com.makeitquick.security.UserRepository;
import com.makeitquick.worker.WorkerProfile;
import com.makeitquick.worker.WorkerProfileRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.annotation.Order;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.Instant;
import java.util.List;

@Component
@Order(30)
@ConditionalOnProperty(name = "app.demo-data.enabled", havingValue = "true", matchIfMissing = true)
public class DemoDataSeeder implements CommandLineRunner {

  private static final Logger log = LoggerFactory.getLogger(DemoDataSeeder.class);
  private static final BCryptPasswordEncoder ENCODER = new BCryptPasswordEncoder(12);

  private final PartnerRepository partners;
  private final UserRepository users;
  private final WorkerProfileRepository workerProfiles;
  private final BookingRepository bookings;
  private final SettingRepository settings;
  private final DisputeRepository disputes;
  private final ReturnRepository returns;
  private final SupportRepository support;
  private final PaymentRepository payments;
  private final Path uploadDir;

  public DemoDataSeeder(PartnerRepository partners, UserRepository users,
                        WorkerProfileRepository workerProfiles, BookingRepository bookings,
                        SettingRepository settings, DisputeRepository disputes,
                        ReturnRepository returns, SupportRepository support,
                        PaymentRepository payments,
                        @Value("${app.uploads-dir:uploads}") String uploadsDir) {
    this.partners = partners;
    this.users = users;
    this.workerProfiles = workerProfiles;
    this.bookings = bookings;
    this.settings = settings;
    this.disputes = disputes;
    this.returns = returns;
    this.support = support;
    this.payments = payments;
    this.uploadDir = Paths.get(uploadsDir).toAbsolutePath().normalize();
  }

  @Override
  @Transactional
  public void run(String... args) throws Exception {
    ensureCommissionSetting();
    seedCustomersAndWorkers();
    seedBookingsAndPayments();
    seedDisputes();
    seedSupportData();

    if (partners.count() > 0) {
      return;
    }
    log.info("Seeding demo partners, KYC documents and live bookings…");

    Partner anita = seedPartner("Anita Deshmukh", "+919845001101", "anita.d@gmail.com", "AADHAAR",
        "Anita Deshmukh", "502812047101", "HDFC0001234", "anita.d@okaxis",
        "PENDING", null, 19.0667, 72.8450, "Sector 15, Nerul, Navi Mumbai");
    Partner meera = seedPartner("Meera Nair", "+919845001102", "meera.nair@gmail.com", "DRIVING_LICENSE",
        "Meera Nair", "502812047102", "ICIC0005678", "meera.n@oksbi",
        "PENDING", null, 19.1082, 72.8317, "Chandivali, Andheri East, Mumbai");
    Partner sunita = seedPartner("Sunita Yadav", "+919845001103", "sunita.y@gmail.com", "GOVT_ID",
        "Sunita Yadav", "502812047103", "SBIN0002345", "sunita.y@okhdfcbank",
        "PENDING", null, 19.0193, 72.8460, "Vashi, Navi Mumbai");
    Partner priya = seedPartner("Priya Sharma", "+919845001104", "priya.s@gmail.com", "AADHAAR",
        "Priya Sharma", "502812047104", "HDFC0001234", "priya.s@okaxis",
        "APPROVED", Instant.now().minusSeconds(86400 * 5), 19.0760, 72.8777, "Powai, Mumbai");
    Partner lakshmi = seedPartner("Lakshmi Iyer", "+919845001105", "lakshmi.i@gmail.com", "AADHAAR",
        "Lakshmi Iyer", "502812047105", "KMBL0000456", "lakshmi.i@okhdfcbank",
        "APPROVED", Instant.now().minusSeconds(86400 * 3), 18.9633, 72.8320, "Colaba, Mumbai");
    Partner reena = seedPartner("Reena Kulkarni", "+919845001106", "reena.k@gmail.com", "DRIVING_LICENSE",
        "Reena Kulkarni", "502812047106", "HDFC0001234", "reena.k@oksbi",
        "APPROVED", Instant.now().minusSeconds(86400 * 2), 19.1369, 72.8903, "Mulund West, Mumbai");
    Partner kavita = seedPartner("Kavita Patil", "+919845001107", "kavita.p@gmail.com", "GOVT_ID",
        "Kavita Patil", "502812047107", "SBIN0002345", "kavita.p@okaxis",
        "REJECTED", null, 19.0600, 72.8470, "Airoli, Navi Mumbai");
    Partner pooja = seedPartner("Pooja Jadhav", "+919845001108", "pooja.j@gmail.com", "AADHAAR",
        "Pooja Jadhav", "502812047108", "ICIC0005678", "pooja.j@okhdfcbank",
        "REJECTED", null, 19.1154, 72.9070, "Bhandup West, Mumbai");

    kavita.setRejectionReason("Blurry ID photo — please re-upload a clear copy of your government ID.");
    pooja.setRejectionReason("Invalid IFSC code — the bank details could not be verified. Enter the correct IFSC and resubmit.");
    partners.save(kavita);
    partners.save(pooja);

    seedDocs(anita, "ANITA DESHMUKH", "AADHAAR", "5028 1204 7101", "Electricity bill - Tata Power, Nerul");
    seedDocs(meera, "MEERA NAIR", "DRIVING LICENCE", "MH-02-2018-045678", "Rent agreement, Chandivali");
    seedDocs(sunita, "SUNITA YADAV", "VOTER ID", "VXN1234567", "Aadhaar-linked address proof, Vashi");
    seedDocs(priya, "PRIYA SHARMA", "AADHAAR", "5128 8899 1042", "Property tax receipt, Powai");
    seedDocs(lakshmi, "LAKSHMI IYER", "AADHAAR", "4876 3345 2910", "Bank statement, Colaba");
    seedDocs(reena, "REENA KULKARNI", "DRIVING LICENCE", "MH-04-2019-112233", "LPG bill, Mulund");
  }

  private void ensureCommissionSetting() {
    if (settings.existsBySettingKey("platform_commission_pct")) return;
    Setting s = new Setting();
    s.setSettingKey("platform_commission_pct");
    s.setSettingValue("18");
    s.setDescription("Platform commission percentage applied to every booking payout");
    settings.save(s);
  }

  private void seedCustomersAndWorkers() {
    if (users.countByRole(Role.CUSTOMER) > 0 && users.countByRole(Role.WORKER) > 0) {
      return;
    }
    log.info("Seeding demo customers and workers…");
    seedCustomer("Rohit Malhotra", "rohit.m@example.com", "+919845002001");
    seedCustomer("Sneha Kulkarni", "sneha.k@example.com", "+919845002002");
    seedCustomer("Vikram Singh", "vikram.s@example.com", "+919845002003");
    seedCustomer("Aarti Deshpande", "aarti.d@example.com", "+919845002004");

    seedWorker("Meera Nair", "meera.nair@example.com", "+919845001102", 19.1082, 72.8317);
    seedWorker("Priya Sharma", "priya.s@example.com", "+919845001104", 19.0760, 72.8777);
    seedWorker("Lakshmi Iyer", "lakshmi.i@example.com", "+919845001105", 18.9633, 72.8320);
    seedWorker("Reena Kulkarni", "reena.k@example.com", "+919845001106", 19.1369, 72.8903);
  }

  private void seedCustomer(String name, String email, String phone) {
    users.findByPhoneAndRole(phone, Role.CUSTOMER)
        .orElseGet(() -> users.save(new UserAccount(name, email,
            ENCODER.encode("demo-pass-" + System.currentTimeMillis()), phone, Role.CUSTOMER)));
  }

  private void seedWorker(String name, String email, String phone, double lat, double lng) {
    if (users.findByPhoneAndRole(phone, Role.WORKER).isPresent()) {
      return;
    }
    UserAccount worker = users.save(new UserAccount(name, email,
        ENCODER.encode("demo-pass-" + System.currentTimeMillis()), phone, Role.WORKER));
    WorkerProfile profile = new WorkerProfile(worker);
    profile.acceptConsent();
    profile.submitKyc("ref-" + worker.getId());
    profile.submitPan("PAN" + worker.getId(), name, "ref-pan-" + worker.getId());
    profile.submitSelfie("ref-selfie-" + worker.getId());
    profile.submitAddress("Mumbai", "Mumbai", "Mumbai", "Maharashtra", "400001", "ref-addr-" + worker.getId());
    profile.submitPoliceVerification("ref-police-" + worker.getId());
    profile.setPayout("BANK", name, "7890", "HDFC0001234", name + "@upi");
    profile.submitServiceReadiness("home-cleaning", "mumbai", "5 years experience", "anytime", true);
    profile.approve();
    profile.setAvailability(AvailabilityStatus.AVAILABLE);
    profile.updateLocation(lat, lng);
    workerProfiles.save(profile);
  }

  private void seedBookingsAndPayments() {
    if (bookings.count() > 0) {
      return;
    }
    List<UserAccount> customers = users.findAll().stream().filter(u -> u.getRole() == Role.CUSTOMER).toList();
    List<UserAccount> workers = users.findAll().stream().filter(u -> u.getRole() == Role.WORKER).toList();
    if (customers.isEmpty()) {
      return;
    }
    log.info("Seeding demo bookings and payments…");
    Instant now = Instant.now();
    String[] services = {"Full Home Cleaning", "Deep Cleaning", "Kitchen Cleaning",
        "Bathroom Cleaning", "Regular Housekeeping", "Balcony Cleaning"};
    double[][] points = {
        {19.0667, 72.8450}, {19.1082, 72.8317}, {19.0760, 72.8777},
        {18.9633, 72.8320}, {19.1369, 72.8903}, {19.0193, 72.8460}};
    String[] addresses = {
        "Flat 402, Sea Breeze, Nerul", "Bungalow 12, Chandivali Farm Road", "Tower B-1204, Powai",
        "2BHK, Colaba Causeway", "Flat 9, Mulund West", "Sector 5, Vashi"};
    int[] paise = {69900, 129900, 89900, 149900, 189900, 119900};
    BookingStatus[] statuses = {BookingStatus.REQUESTED, BookingStatus.SEARCHING,
        BookingStatus.ASSIGNED, BookingStatus.ACCEPTED, BookingStatus.IN_PROGRESS, BookingStatus.COMPLETED};
    UserAccount assignedWorker = workers.isEmpty() ? null : workers.get(0);

    for (int i = 0; i < statuses.length; i++) {
      UserAccount customer = customers.get(i % customers.size());
      Booking b = new Booking(customer, services[i], addresses[i],
          java.time.LocalDateTime.now().plusMinutes(30 + i * 25).toString(),
          "400001", 60, "Standard", null, 0, "");
      b.setPaymentAmountPaise(paise[i]);
      b.setStatus(statuses[i]);
      if (i >= 2 && assignedWorker != null) {
        b.setWorker(assignedWorker);
      }
      bookings.save(b);
    }

    List<Booking> all = bookings.findAll();
    for (Booking b : all) {
      if (b.getStatus() == BookingStatus.COMPLETED) {
        Payment p = new Payment(b, "TXN-DEMO-" + b.getId(), "UPI", b.getPaymentAmountPaise());
        p.markPaid("Demo gateway capture");
        payments.save(p);
      } else if (b.getStatus() == BookingStatus.IN_PROGRESS) {
        Payment p = new Payment(b, "TXN-DEMO-" + b.getId(), "CASH", b.getPaymentAmountPaise());
        payments.save(p);
      }
    }
  }

  private void seedDisputes() {
    List<Booking> all = bookings.findAll();
    if (all.size() < 2) return;
    long open = disputes.findAll().stream().filter(d -> "OPEN".equals(d.getStatus())).count();
    long needs = 2 - open;
    for (long i = 0; i < needs; i++) {
      Booking book = all.get((int) (all.size() - 1 - i));
      Dispute d = new Dispute();
      if (i == 0) {
        d.setBooking(book);
        d.setReporterType("CUSTOMER");
        d.setSubject("Charge discrepancy on completed booking");
        d.setDescription("Customer reports the final amount charged was higher than the quoted price. "
            + "Requesting manual review of the payout split and a possible partial refund.");
      } else {
        d.setBooking(book);
        d.setReporterType("PARTNER");
        d.setSubject("Customer marked no-show after service was completed");
        d.setDescription("Partner claims the service was delivered but the customer reported it as not "
            + "completed. Asking for call logs to be reviewed and the payout to be released.");
      }
      disputes.save(d);
    }
  }

  private Partner seedPartner(String name, String phone, String email, String docType,
                              String holder, String account, String ifsc, String upi,
                              String status, Instant approvedAt, double lat, double lng, String address) {
    Partner p = new Partner();
    p.setName(name);
    p.setPhone(phone);
    p.setEmail(email);
    p.setAddress(address);
    p.setKycStatus(status);
    p.setApprovedAt(approvedAt);
    p.setIdentityDocType(docType);
    p.setBankAccountHolder(holder);
    p.setBankAccountNumber(account);
    p.setBankIfsc(ifsc);
    p.setUpiId(upi);
    p.setLatitude(lat);
    p.setLongitude(lng);
    return partners.save(p);
  }

  private void seedDocs(Partner p, String holderName, String docTitle, String docNumber, String addressLine) throws Exception {
    Path dir = uploadDir.resolve("partners");
    Files.createDirectories(dir);
    Path identity = dir.resolve(p.getId() + "-identity.svg");
    Path address = dir.resolve(p.getId() + "-address.svg");
    Files.writeString(identity, svgDoc(holderName, docTitle, docNumber, addressLine, "IDENTITY PROOF"));
    Files.writeString(address, svgDoc(holderName, "ADDRESS PROOF", addressLine, "MAID IT QUICK VERIFIED COPY", "ADDRESS PROOF"));
    p.setIdentityDocPath("/uploads/partners/" + identity.getFileName());
    p.setAddressDocPath("/uploads/partners/" + address.getFileName());
    partners.save(p);
  }

  private void seedSupportData() {
    List<Booking> all = bookings.findAll();
    List<UserAccount> custs = users.findAll().stream().filter(u -> u.getRole() == Role.CUSTOMER).toList();
    if (returns.count() == 0) {
      List<Booking> done = all.stream().filter(b -> b.getStatus() == BookingStatus.COMPLETED).toList();
      if (!done.isEmpty()) {
        ReturnRequest r1 = new ReturnRequest();
        r1.setBookingId(done.get(0).getId());
        r1.setRequestedAmount(new BigDecimal("1299"));
        r1.setReason("Service was not completed as promised — re-cleaning required and a fold ironing was skipped.");
        r1.setStatus("REQUESTED");
        returns.save(r1);
        if (done.size() > 1) {
          ReturnRequest r2 = new ReturnRequest();
          r2.setBookingId(done.get(1).getId());
          r2.setRequestedAmount(new BigDecimal("699"));
          r2.setReason("Deep-cleaning chemicals caused a mild reaction; customer requested partial refund.");
          r2.setStatus("APPROVED");
          r2.setAdminNote("Approved after supervisor inspection — refund raised to payments.");
          r2.setDecidedAt(Instant.now().minusSeconds(86400));
          returns.save(r2);
        }
      }
    }
    if (support.count() == 0) {
      String c1 = custs.isEmpty() ? "Mobile App User" : custs.get(0).getName();
      String c2 = custs.size() > 1 ? custs.get(1).getName() : "Mobile App User";
      String c3 = custs.size() > 2 ? custs.get(2).getName() : "Mobile App User";
      SupportRequest s1 = new SupportRequest();
      s1.setCustomerName(c1);
      s1.setSubject("Unable to reschedule my booking");
      s1.setMessage("I tried to reschedule my deep-cleaning slot to Saturday but the app keeps showing an error.");
      s1.setStatus("OPEN");
      s1.setPriority("HIGH");
      s1.setCategory("BOOKING");
      support.save(s1);
      SupportRequest s2 = new SupportRequest();
      s2.setCustomerName(c2);
      s2.setSubject("Partner didn't show up");
      s2.setMessage("My partner never arrived at the scheduled time and the booking was left hanging.");
      s2.setStatus("IN_PROGRESS");
      s2.setPriority("HIGH");
      s2.setCategory("PARTNER");
      support.save(s2);
      SupportRequest s3 = new SupportRequest();
      s3.setCustomerName(c3);
      s3.setSubject("How do I pay by UPI?");
      s3.setMessage("Question about payment methods available for the 3-hour maid service.");
      s3.setStatus("RESOLVED");
      s3.setPriority("LOW");
      s3.setCategory("PAYMENT");
      s3.setAdminReply("UPI is supported via any UPI app — select UPI at checkout.");
      s3.setResolvedAt(Instant.now().minusSeconds(2 * 86400));
      support.save(s3);
    }
  }

  private String svgDoc(String holder, String title, String line1, String line2, String badge) {
    return "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"700\" height=\"400\" viewBox=\"0 0 700 400\">"
        + "<defs><linearGradient id=\"g\" x1=\"0\" y1=\"0\" x2=\"1\" y2=\"1\">"
        + "<stop offset=\"0\" stop-color=\"#1e3a8a\"/><stop offset=\"1\" stop-color=\"#4f46e5\"/></linearGradient></defs>"
        + "<rect width=\"700\" height=\"400\" rx=\"16\" fill=\"url(#g)\"/>"
        + "<text x=\"40\" y=\"70\" font-family=\"Arial, sans-serif\" font-size=\"34\" font-weight=\"bold\" fill=\"#ffffff\">"
        + badge + "</text>"
        + "<text x=\"40\" y=\"120\" font-family=\"Arial, sans-serif\" font-size=\"22\" fill=\"#c7d2fe\">MAID IT QUICK - DOCUMENT VERIFICATION COPY</text>"
        + "<rect x=\"40\" y=\"150\" width=\"620\" height=\"1\" fill=\"#c7d2fe\"/>"
        + "<text x=\"40\" y=\"205\" font-family=\"Arial, sans-serif\" font-size=\"26\" fill=\"#ffffff\">" + holder + "</text>"
        + "<text x=\"40\" y=\"245\" font-family=\"Arial, sans-serif\" font-size=\"22\" fill=\"#e0e7ff\">" + title + " : " + line1 + "</text>"
        + "<text x=\"40\" y=\"280\" font-family=\"Arial, sans-serif\" font-size=\"18\" fill=\"#e0e7ff\">" + line2 + "</text>"
        + "<text x=\"40\" y=\"340\" font-family=\"Arial, sans-serif\" font-size=\"16\" fill=\"#94a3b8\">Sample document - generated for demo / verification purposes</text>"
        + "</svg>";
  }
}
