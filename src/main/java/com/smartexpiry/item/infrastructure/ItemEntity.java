package com.smartexpiry.item.infrastructure;

import com.smartexpiry.item.domain.ItemLifecycleStatus;
import jakarta.persistence.*;

import java.time.Instant;

@Entity
@Table(name = "item")
public class ItemEntity {
    @Id
    private String id;

    @Column(name = "owner_id", length = 36)
    private String ownerId;

    @Column(nullable = false, length = 120)
    private String name;

    @Column(name = "category_id", nullable = false)
    private String categoryId;

    @Column(length = 120)
    private String brand;

    @Enumerated(EnumType.STRING)
    @Column(name = "lifecycle_status", nullable = false, length = 32)
    private ItemLifecycleStatus lifecycleStatus;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "deleted_at")
    private Instant deletedAt;

    @Version
    private long version;

    protected ItemEntity() {}

    public ItemEntity(String id, String name, String categoryId, String brand, ItemLifecycleStatus lifecycleStatus,
                      Instant createdAt, Instant updatedAt) {
        this.id = id;
        this.name = name;
        this.categoryId = categoryId;
        this.brand = brand;
        this.lifecycleStatus = lifecycleStatus;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
    }

    public String getId() { return id; }
    public String getOwnerId() { return ownerId; }
    public void assignOwner(String ownerId) { this.ownerId = ownerId; }
    public String getName() { return name; }
    public String getCategoryId() { return categoryId; }
    public String getBrand() { return brand; }
    public ItemLifecycleStatus getLifecycleStatus() { return lifecycleStatus; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
    public Instant getDeletedAt() { return deletedAt; }

    public void update(String name, String categoryId, String brand, Instant now) {
        this.name = name;
        this.categoryId = categoryId;
        this.brand = brand;
        this.updatedAt = now;
    }

    public void softDelete(Instant now) {
        this.deletedAt = now;
        this.updatedAt = now;
    }

    public void changeLifecycle(ItemLifecycleStatus status, Instant now) {
        this.lifecycleStatus = status;
        this.updatedAt = now;
    }
}
