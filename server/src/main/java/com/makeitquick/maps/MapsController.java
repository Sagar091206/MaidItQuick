package com.makeitquick.maps;

import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/maps")
@CrossOrigin(origins = "*")
public class MapsController {
  private final String browserKey;

  public MapsController(@Value("${GOOGLE_MAPS_BROWSER_KEY:}") String browserKey) {
    this.browserKey = browserKey;
  }

  @GetMapping("/browser-key")
  public Map<String, String> browserKey() {
    return Map.of("key", browserKey);
  }
}
