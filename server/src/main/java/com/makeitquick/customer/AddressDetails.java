package com.makeitquick.customer;

record AddressDetails(
        String label,
        String houseNumber,
        String building,
        String street,
        String area,
        String landmark,
        String city,
        String state,
        String pinCode,
        Double latitude,
        Double longitude) {}
