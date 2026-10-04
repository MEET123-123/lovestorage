package com.smartexpiry.item.infrastructure;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface InventoryBatchJpaRepository extends JpaRepository<InventoryBatchEntity, String> {
    java.util.List<InventoryBatchEntity> findByItemIdInOrderByCreatedAtAsc(java.util.List<String> itemIds);
    Optional<InventoryBatchEntity> findFirstByItemIdOrderByCreatedAtAsc(String itemId);
}
