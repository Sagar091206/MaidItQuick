package com.maiditquick.admin.config;

import com.maiditquick.admin.bookings.Booking;
import com.maiditquick.admin.bookings.BookingRepository;
import com.maiditquick.admin.customers.Customer;
import com.maiditquick.admin.customers.CustomerRepository;
import com.maiditquick.admin.escalations.Dispute;
import com.maiditquick.admin.escalations.DisputeRepository;
import com.maiditquick.admin.partners.Partner;
import com.maiditquick.admin.partners.PartnerRepository;
import com.maiditquick.admin.payments.Payment;
import com.maiditquick.admin.payments.PaymentRepository;
import com.maiditquick.admin.returns.ReturnRequest;
import com.maiditquick.admin.returns.ReturnRepository;
import com.maiditquick.admin.services.ServiceOffering;
import com.maiditquick.admin.services.ServiceOfferingRepository;
import com.maiditquick.admin.settings.Setting;
import com.maiditquick.admin.settings.SettingRepository;
import com.maiditquick.admin.support.SupportRepository;
import com.maiditquick.admin.support.SupportRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.core.annotation.Order;
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
public class DemoDataSeeder implements CommandLineRunner {

  private static final Logger log = LoggerFactory.getLogger(DemoDataSeeder.class);

  private final PartnerRepository partners;
  private final CustomerRepository customers;
  private final ServiceOfferingRepository services;
  private final BookingRepository bookings;
  private final SettingRepository settings;
  private final DisputeRepository disputes;
  private final ReturnRepository returns;
  private final SupportRepository support;
  private final PaymentRepository payments;
  private final Path uploadDir;

  public DemoDataSeeder(PartnerRepository partners, CustomerRepository customers,
                        ServiceOfferingRepository services, BookingRepository bookings,
                        SettingRepository settings, DisputeRepository disputes,
                        ReturnRepository returns, SupportRepository support,
                        PaymentRepository payments,
                        @Value("${app.uploads-dir:uploads}") String uploadsDir) {
    this.partners = partners;
    this.customers = customers;
    this.services = services;
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
    seedDisputes();
    seedSupportData();
    seedPayments();

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

    seedLiveBookings(priya, lakshmi, reena);
    seedCompletedBooking(priya);
  }

  private void ensureCommissionSetting() {
    if (settings.existsBySettingKey("platform_commission_pct")) return;
    Setting s = new Setting();
    s.setSettingKey("platform_commission_pct");
    s.setSettingValue("18");
    s.setDescription("Platform commission percentage applied to every booking payout");
    settings.save(s);
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

  private void seedLiveBookings(Partner priya, Partner lakshmi, Partner reena) {
    List<Customer> customers = this.customers.findAll();
    List<ServiceOffering> services = this.services.findAll();
    if (customers.isEmpty() || services.isEmpty()) return;

    double[][] points = {
        {19.0667, 72.8450}, {19.1082, 72.8317}, {19.0760, 72.8777},
        {18.9633, 72.8320}, {19.1369, 72.8903}, {19.0193, 72.8460}};
    String[] statuses = {"PENDING", "PENDING", "CONFIRMED", "CONFIRMED", "IN_PROGRESS", "IN_PROGRESS"};
    Partner[] assigned = {null, null, priya, lakshmi, reena, priya};
    BigDecimal[] amounts = {new BigDecimal("699"), new BigDecimal("1299"), new BigDecimal("899"),
        new BigDecimal("1499"), new BigDecimal("1899"), new BigDecimal("1199")};
    String[] addresses = {
        "Flat 402, Sea Breeze, Nerul", "Bungalow 12, Chandivali Farm Road", "Tower B-1204, Powai",
        "2BHK, Colaba Causeway", "Flat 9, Mulund West", "Sector 5, Vashi"};
    Instant now = Instant.now();

    for (int i = 0; i < statuses.length; i++) {
      Booking b = new Booking();
      b.setCustomer(customers.get(i % customers.size()));
      b.setService(services.get(i % services.size()));
      b.setPartner(assigned[i]);
      b.setStatus(statuses[i]);
      b.setAddress(addresses[i]);
      b.setTotalAmount(amounts[i]);
      b.setLatitude(points[i][0]);
      b.setLongitude(points[i][1]);
      b.setCreatedAt(now.minusSeconds((long) (90 + i * 17) * 60));
      b.setScheduledAt(java.time.LocalDateTime.now().plusMinutes(30 + i * 25));
      if ("IN_PROGRESS".equals(statuses[i])) {
        b.setStartedAt(now.minusSeconds(45 * 60L + i * 7 * 60L));
      }
      bookings.save(b);
    }
  }

  private void seedCompletedBooking(Partner partner) {
    List<Customer> customers = this.customers.findAll();
    List<ServiceOffering> services = this.services.findAll();
    if (customers.isEmpty() || services.isEmpty()) return;
    Booking b = new Booking();
    b.setCustomer(customers.get(customers.size() - 1));
    b.setService(services.get(services.size() % services.size()));
    b.setPartner(partner);
    b.setStatus("COMPLETED");
    b.setAddress("Flat 12, Seawoods Grand Central, Navi Mumbai");
    b.setTotalAmount(new BigDecimal("1599"));
    b.setLatitude(19.0212);
    b.setLongitude(73.0213);
    Instant now = Instant.now();
    b.setCreatedAt(now.minusSeconds(2 * 86400));
    b.setStartedAt(now.minusSeconds(2 * 86400 + 3600));
    b.setCompletedAt(now.minusSeconds(2 * 86400 + 7200));
    bookings.save(b);
  }

  private void seedPayments() {
    if (payments.count() > 0) return;
    List<Booking> all = bookings.findAll();
    if (all.isEmpty()) return;
    String[] methods = {"CASH", "CARD", "ONLINE", "BANK_TRANSFER"};
    int m = 0;
    for (Booking b : all) {
      String status;
      switch (b.getStatus()) {
        case "COMPLETED", "CONFIRMED", "IN_PROGRESS" -> status = "PAID";
        default -> status = "PENDING";
      }
      if (b.getId() % 5 == 0) status = "FAILED";
      Payment p = new Payment();
      p.setBooking(b);
      p.setAmount(b.getTotalAmount());
      p.setMethod(methods[m++ % methods.length]);
      p.setStatus(status);
      p.setTransactionId("TXN" + System.currentTimeMillis() % 1000000000L + b.getId());
      if ("PAID".equals(status)) {
        p.setPaidAt(Instant.now().minusSeconds(3600L + b.getId() * 3600L));
      }
      payments.save(p);
    }
    log.info("Seeded {} demo payments", payments.count());
  }

  private void seedSupportData() {
    List<Booking> all = bookings.findAll();
    List<Customer> custs = customers.findAll();
    if (returns.count() == 0) {
      List<Booking> done = all.stream().filter(b -> "COMPLETED".equals(b.getStatus())).toList();
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
