package com.makeitquick.booking;
import com.makeitquick.admin.settings.SettingRepository;
import java.math.*; import org.springframework.stereotype.Service;
@Service
public class CommissionService {
 private final SettingRepository settings; public CommissionService(SettingRepository s){settings=s;}
 public BigDecimal currentPct(){return settings.findBySettingKey("platform_commission_pct").map(s->{try{return new BigDecimal(s.getSettingValue());}catch(Exception e){return BigDecimal.valueOf(20);}}).orElse(BigDecimal.valueOf(20));}
 public Split split(int customerPaise){BigDecimal pct=currentPct();int fee=BigDecimal.valueOf(customerPaise).multiply(pct).divide(BigDecimal.valueOf(100),0,RoundingMode.HALF_UP).intValueExact();return new Split(pct,fee,customerPaise-fee);}
 public record Split(BigDecimal percentage,int commissionPaise,int workerPayoutPaise){}
}
