package com.makeitquick.promo;

public record DiscountResult(
        DiscountType type,
        int percentage,
        int discountPaise,
        String promoCode,
        String message
) {
    public static DiscountResult none() {
        return new DiscountResult(DiscountType.NONE, 0, 0, "", "");
    }

    public static DiscountResult firstOrder(int percentage, int discountPaise) {
        return new DiscountResult(
                DiscountType.FIRST_ORDER,
                percentage,
                discountPaise,
                "",
                "First-order discount (" + percentage + "% off)"
        );
    }

    public static DiscountResult promo(String code, int percentage, int discountPaise) {
        return new DiscountResult(
                DiscountType.PROMO_CODE,
                percentage,
                discountPaise,
                code,
                "Promo code " + code + " applied (" + percentage + "% off)"
        );
    }
}
