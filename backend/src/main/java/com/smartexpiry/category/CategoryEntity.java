package com.smartexpiry.category;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "category")
public class CategoryEntity {
    @Id
    private String id;
    @Column(nullable = false)
    private String name;
    @Column(nullable = false)
    private String type;
    @Column(name = "is_system", nullable = false)
    private boolean system;

    protected CategoryEntity() {}

    public String getId() { return id; }
    public String getName() { return name; }
    public String getType() { return type; }
    public boolean isSystem() { return system; }
}
