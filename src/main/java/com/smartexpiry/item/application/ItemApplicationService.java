package com.smartexpiry.item.application;

import com.smartexpiry.category.CategoryRepository;
import com.smartexpiry.auth.AuthService;
import com.smartexpiry.common.exception.BusinessException;
import com.smartexpiry.expiry.domain.ExpiryEvaluation;
import com.smartexpiry.expiry.domain.ExpiryService;
import com.smartexpiry.item.api.CreateItemRequest;
import com.smartexpiry.item.api.ItemResponse;
import com.smartexpiry.item.api.UpdateItemRequest;
import com.smartexpiry.item.domain.ItemLifecycleStatus;
import com.smartexpiry.item.infrastructure.InventoryBatchEntity;
import com.smartexpiry.item.infrastructure.InventoryBatchJpaRepository;
import com.smartexpiry.item.infrastructure.ItemEntity;
import com.smartexpiry.item.infrastructure.ItemJpaRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@Service
public class ItemApplicationService {
    private static final int DEFAULT_REMINDER_DAYS = 7;

    private final ItemJpaRepository itemRepository;
    private final InventoryBatchJpaRepository batchRepository;
    private final CategoryRepository categoryRepository;
    private final ExpiryService expiryService;
    private final Clock clock;

    @org.springframework.beans.factory.annotation.Autowired
    public ItemApplicationService(ItemJpaRepository itemRepository,
                                  InventoryBatchJpaRepository batchRepository,
                                  CategoryRepository categoryRepository,
                                  ExpiryService expiryService) {
        this(itemRepository, batchRepository, categoryRepository, expiryService,
            Clock.system(java.time.ZoneId.of("Asia/Shanghai")));
    }

    ItemApplicationService(ItemJpaRepository itemRepository,
                           InventoryBatchJpaRepository batchRepository,
                           CategoryRepository categoryRepository,
                           ExpiryService expiryService,
                           Clock clock) {
        this.itemRepository = itemRepository;
        this.batchRepository = batchRepository;
        this.categoryRepository = categoryRepository;
        this.expiryService = expiryService;
        this.clock = clock;
    }

    @Transactional
    public ItemResponse create(CreateItemRequest request) {
        if (request.clientId() != null && itemRepository.existsById(request.clientId())) {
            return get(request.clientId());
        }
        requireCategory(request.categoryId());
        validateShelfLife(request.productionDate(), request.expiryDate(), request.shelfLifeValue(), request.shelfLifeUnit());
        Instant now = Instant.now(clock);
        String itemId = request.clientId() == null ? UUID.randomUUID().toString() : request.clientId();
        LocalDate expiryDate = request.expiryDate() != null
            ? request.expiryDate()
            : expiryService.deriveExpiryDate(request.productionDate(), request.shelfLifeValue(), request.shelfLifeUnit());

        validateDates(request.productionDate(), expiryDate, request.openedDate(), request.afterOpenValue(), request.afterOpenUnit());
        ItemEntity item = new ItemEntity(itemId, request.name().trim(), request.categoryId(), request.brand(),
            ItemLifecycleStatus.ACTIVE, now, now);
        item.assignOwner(AuthService.userId());
        itemRepository.save(item);

        InventoryBatchEntity batch = new InventoryBatchEntity(
            UUID.randomUUID().toString(), itemId,
            request.quantity() == null ? BigDecimal.ONE : request.quantity(), request.unit(),
            request.productionDate(), expiryDate, request.shelfLifeValue(), request.shelfLifeUnit(),
            request.openedDate(), request.afterOpenValue(), request.afterOpenUnit(), now, now
        );
        batchRepository.save(batch);
        return toResponse(item, batch);
    }

    @Transactional(readOnly = true)
    public List<ItemResponse> list() {
        return itemRepository.findByOwnerIdAndDeletedAtIsNullOrderByUpdatedAtDesc(AuthService.userId()).stream()
            .map(item -> toResponse(item, findBatch(item.getId())))
            .toList();
    }

    @Transactional(readOnly = true)
    public ItemResponse get(String id) {
        ItemEntity item = findItem(id);
        return toResponse(item, findBatch(item.getId()));
    }

    @Transactional
    public ItemResponse update(String id, UpdateItemRequest request) {
        ItemEntity item = findItem(id);
        InventoryBatchEntity batch = findBatch(id);
        Instant now = Instant.now(clock);

        if (request.categoryId() != null) requireCategory(request.categoryId());
        if (request.lifecycleStatus() != null) item.changeLifecycle(request.lifecycleStatus(), now);
        if (request.name() != null && request.name().isBlank())
            throw new BusinessException(100001, "name must not be blank");
        item.update(request.name() == null ? item.getName() : request.name().trim(),
            request.categoryId() == null ? item.getCategoryId() : request.categoryId(),
            request.brand() == null ? item.getBrand() : request.brand(), now);
        BigDecimal quantity = request.quantity() == null ? batch.getQuantity() : request.quantity();
        String unit = request.unit() == null ? batch.getUnit() : request.unit();
        LocalDate production = request.productionDate() == null ? batch.getProductionDate() : request.productionDate();
        Integer life = request.shelfLifeValue() == null ? batch.getShelfLifeValue() : request.shelfLifeValue();
        var lifeUnit = request.shelfLifeUnit() == null ? batch.getShelfLifeUnit() : request.shelfLifeUnit();
        LocalDate expiry = request.expiryDate() == null ? batch.getExpiryDate() : request.expiryDate();
        if (request.expiryDate() == null && (request.productionDate() != null || request.shelfLifeValue() != null || request.shelfLifeUnit() != null)) {
            LocalDate derived = expiryService.deriveExpiryDate(production, life, lifeUnit);
            if (derived != null) expiry = derived;
        }
        LocalDate opened = request.openedDate() == null ? batch.getOpenedDate() : request.openedDate();
        Integer after = request.afterOpenValue() == null ? batch.getAfterOpenValue() : request.afterOpenValue();
        var afterUnit = request.afterOpenUnit() == null ? batch.getAfterOpenUnit() : request.afterOpenUnit();
        validateShelfLife(production, expiry, life, lifeUnit);
        validateDates(production, expiry, opened, after, afterUnit);
        batch.update(quantity, unit, production, expiry, life, lifeUnit, opened, after, afterUnit, now);
        return toResponse(item, batch);
    }

    @Transactional
    public void delete(String id) {
        findItem(id).softDelete(Instant.now(clock));
    }

    private ItemResponse toResponse(ItemEntity item, InventoryBatchEntity batch) {
        ExpiryEvaluation evaluation = expiryService.evaluate(batch.getExpiryDate(), batch.getOpenedDate(),
            batch.getAfterOpenValue(), batch.getAfterOpenUnit(), "cosmetics".equals(item.getCategoryId()) ? 30 : DEFAULT_REMINDER_DAYS, LocalDate.now(clock));
        return new ItemResponse(item.getId(), item.getName(), item.getCategoryId(), item.getBrand(),
            item.getLifecycleStatus(), batch.getQuantity(), batch.getUnit(), batch.getProductionDate(),
            batch.getExpiryDate(), evaluation.effectiveExpiryDate(), evaluation.remainingDays(), evaluation.status(),
            item.getCreatedAt(), item.getUpdatedAt());
    }

    private ItemEntity findItem(String id) {
        return itemRepository.findByIdAndOwnerIdAndDeletedAtIsNull(id, AuthService.userId())
            .orElseThrow(() -> new BusinessException(300001, "item not found"));
    }

    private InventoryBatchEntity findBatch(String id) {
        return batchRepository.findFirstByItemIdOrderByCreatedAtAsc(id)
            .orElseThrow(() -> new BusinessException(300002, "inventory batch not found"));
    }

    private void requireCategory(String id) {
        if (!categoryRepository.existsById(id)) throw new BusinessException(300003, "category not found");
    }

    private void validateShelfLife(LocalDate production, LocalDate expiry, Integer value,
                                   com.smartexpiry.expiry.domain.ShelfLifeUnit unit) {
        if (expiry == null && (production == null || value == null || unit == null))
            throw new BusinessException(300004, "expiryDate or productionDate+shelfLifeValue+shelfLifeUnit is required");
        if ((value == null) != (unit == null))
            throw new BusinessException(300004, "shelf life value and unit must be provided together");
    }

    private void validateDates(LocalDate production, LocalDate expiry, LocalDate opened, Integer after,
                               com.smartexpiry.expiry.domain.ShelfLifeUnit unit) {
        if (java.util.stream.Stream.of(production, expiry, opened).filter(java.util.Objects::nonNull).anyMatch(d -> d.getYear() < 1900 || d.getYear() > 9999))
            throw new BusinessException(300004, "date year must be between 1900 and 9999");
        if (after != null && opened == null) throw new BusinessException(300004, "openedDate is required for after-open duration");
        if (opened != null && opened.isAfter(LocalDate.now(clock))) throw new BusinessException(300004, "openedDate must not be in the future");
        if (production != null && expiry != null && expiry.isBefore(production))
            throw new BusinessException(300004, "expiryDate must not precede productionDate");
        if ((after == null) != (unit == null))
            throw new BusinessException(300004, "after-open value and unit must be provided together");
        if (opened != null && production != null && opened.isBefore(production))
            throw new BusinessException(300004, "openedDate must not precede productionDate");
    }
}
