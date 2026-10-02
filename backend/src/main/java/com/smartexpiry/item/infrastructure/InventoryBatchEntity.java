package com.smartexpiry.item.infrastructure;

import com.smartexpiry.expiry.domain.ShelfLifeUnit;
import jakarta.persistence.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;

@Entity
@Table(name = "inventory_batch")
public class InventoryBatchEntity {
    @Id
    private String id;

    @Column(name = "item_id", nullable = false)
    private String itemId;

    @Column(nullable = false, precision = 12, scale = 3)
    private BigDecimal quantity;

    @Column(length = 32)
    private String unit;

    @Column(name = "production_date")
    private LocalDate productionDate;

    @Column(name = "expiry_date")
    private LocalDate expiryDate;

    @Column(name = "shelf_life_value")
    private Integer shelfLifeValue;

    @Enumerated(EnumType.STRING)
    @Column(name = "shelf_life_unit")
    private ShelfLifeUnit shelfLifeUnit;

    @Column(name = "opened_date")
    private LocalDate openedDate;

    @Column(name = "after_open_value")
    private Integer afterOpenValue;

    @Enumerated(EnumType.STRING)
    @Column(name = "after_open_unit")
    private ShelfLifeUnit afterOpenUnit;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected InventoryBatchEntity() {}

    public InventoryBatchEntity(String id, String itemId, BigDecimal quantity, String unit,
                                LocalDate productionDate, LocalDate expiryDate,
                                Integer shelfLifeValue, ShelfLifeUnit shelfLifeUnit,
                                LocalDate openedDate, Integer afterOpenValue, ShelfLifeUnit afterOpenUnit,
                                Instant createdAt, Instant updatedAt) {
        this.id = id;
        this.itemId = itemId;
        this.quantity = quantity;
        this.unit = unit;
        this.productionDate = productionDate;
        this.expiryDate = expiryDate;
        this.shelfLifeValue = shelfLifeValue;
        this.shelfLifeUnit = shelfLifeUnit;
        this.openedDate = openedDate;
        this.afterOpenValue = afterOpenValue;
        this.afterOpenUnit = afterOpenUnit;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
    }

    public String getId() { return id; }
    public String getItemId() { return itemId; }
    public BigDecimal getQuantity() { return quantity; }
    public String getUnit() { return unit; }
    public LocalDate getProductionDate() { return productionDate; }
    public LocalDate getExpiryDate() { return expiryDate; }
    public Integer getShelfLifeValue() { return shelfLifeValue; }
    public ShelfLifeUnit getShelfLifeUnit() { return shelfLifeUnit; }
    public LocalDate getOpenedDate() { return openedDate; }
    public Integer getAfterOpenValue() { return afterOpenValue; }
    public ShelfLifeUnit getAfterOpenUnit() { return afterOpenUnit; }

    public void update(BigDecimal quantity, String unit, LocalDate productionDate, LocalDate expiryDate,
                       Integer shelfLifeValue, ShelfLifeUnit shelfLifeUnit, LocalDate openedDate,
                       Integer afterOpenValue, ShelfLifeUnit afterOpenUnit, Instant now) {
        this.quantity = quantity;
        this.unit = unit;
        this.productionDate = productionDate;
        this.expiryDate = expiryDate;
        this.shelfLifeValue = shelfLifeValue;
        this.shelfLifeUnit = shelfLifeUnit;
        this.openedDate = openedDate;
        this.afterOpenValue = afterOpenValue;
        this.afterOpenUnit = afterOpenUnit;
        this.updatedAt = now;
    }
}
