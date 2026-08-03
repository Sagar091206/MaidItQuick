package com.makeitquick.security.sms;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * Development SMS sender that logs the OTP instead of delivering it.
 *
 * <p>Active while {@code app.sms.enabled} is false (the default). The
 * authentication endpoints echo the generated code back as {@code devOtp}
 * only in this mode so local and e2e testing can complete without a provider.
 */
@Component
@ConditionalOnProperty(name = "app.sms.enabled", havingValue = "false", matchIfMissing = true)
public class LoggingSmsSender implements SmsSender {
    private static final Logger log = LoggerFactory.getLogger(LoggingSmsSender.class);

    @Override
    public void sendOtp(String phone, String otp, String purpose) {
        log.info("[dev SMS] {} -> {}: OTP {}", purpose, phone, otp);
    }
}
