package com.maiditquick.admin.common;

import org.springframework.data.domain.Page;

import java.util.List;
import java.util.function.Function;

public record PageResponse<T>(List<T> items, int page, int size, long total, int totalPages) {

  public static <T> PageResponse<T> from(Page<T> page) {
    return new PageResponse<>(page.getContent(), page.getNumber(), page.getSize(), page.getTotalElements(), page.getTotalPages());
  }

  public static <S, T> PageResponse<T> from(Page<S> page, Function<S, T> mapper) {
    return new PageResponse<>(page.getContent().stream().map(mapper).toList(), page.getNumber(), page.getSize(), page.getTotalElements(), page.getTotalPages());
  }

  public static <T> PageResponse<T> of(List<T> items, int page, int size, long total) {
    int pages = size == 0 ? 0 : (int) Math.ceil((double) total / size);
    return new PageResponse<>(items, page, size, total, pages);
  }
}
