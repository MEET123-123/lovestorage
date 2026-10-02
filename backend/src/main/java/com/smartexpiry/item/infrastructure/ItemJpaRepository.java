package com.smartexpiry.item.infrastructure;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface ItemJpaRepository extends JpaRepository<ItemEntity, String> {
    List<ItemEntity> findByDeletedAtIsNullOrderByUpdatedAtDesc();
    Optional<ItemEntity> findByIdAndDeletedAtIsNull(String id);
}
