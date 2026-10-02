package com.smartexpiry.item.application;

import com.smartexpiry.category.CategoryRepository;
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

    public ItemApplicationService(ItemJpaRepository itemRepository,
                                  InventoryBatchJpaRepository batchRepository,
                                  CategoryRepository categoryRepository,
                                  ExpiryService expiryService) {
        this(itemRepository, batchRepository, categoryRepository, expiryService, Clock.systemUTC());
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
        requireCategory(request.categoryId());
        validateShelfLife(request.productionDate(), request.expiryDate(), request.shelfLifeValue(), request.shelfLifeUnit());
        Instant now = Instant.now(clock);
        String itemId = UUID.randomUUID().toString();
        LocalDate expiryDate = request.expiryDate() != null
            ? request.expiryDate()
            : expiryService.deriveExpiryDate(request.productionDate(), request.shelfLifeValue(), request.shelfLifeUnit());

        ItemEntity item = new ItemEntity(itemId, request.name(), request.categoryId(), request.brand(),
            ItemLifecycleStatus.ACTIVE, now, now);
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
        return itemRepository.findByDeletedAtIsNullOrderByUpdatedAtDesc().stream()
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

        if (request.categoryId() != null¤ì(€€€€€€€€€€€É•ÅÕ¥É•…Ñ•½Éä¡É•ÅÕ•ÍĞ¹…Ñ•½Éå% ¤¤ì(€€€€€€€ô(€€€€€€€¥Ñ•´¹ÕÁ‘…Ñ” (€€€€€€€€€€€É•ÅÕ•ÍĞ¹¹…µ” ¤€ôô¹Õ±°€ü¥Ñ•´¹•Ñ9…µ” ¤€èÉ•ÅÕ•ÍĞ¹¹…µ” ¤°(€€€€€€€€€€€É•ÅÕ•ÍĞ¹…Ñ•½Éå% ¤€ôô¹Õ±°€ü¥Ñ•´¹•Ñ…Ñ•½Éå% ¤€èÉ•ÅÕ•ÍĞ¹…Ñ•½Éå% ¤°(€€€€€€€€€€€É•ÅÕ•ÍĞ¹‰É…¹ ¤€ôô¹Õ±°€ü¥Ñ•´¹•Ñ	É…¹ ¤€èÉ•ÅÕ•ÍĞ¹‰É…¹ ¤°(€€€€€€€€€€€¹½Ü(€€€€€€€€¤ì((€€€€€€€	¥•¥µ…°ÅÕ…¹Ñ¥Ñä€ôÉ•ÅÕ•ÍĞ¹ÅÕ…¹Ñ¥Ñä ¤€ôô¹Õ±°€ü‰…Ñ ¹•ÑEÕ…¹Ñ¥Ñä ¤€èÉ•ÅÕ•ÍĞ¹ÅÕ…¹Ñ¥Ñä ¤ì(€€€€€€€MÑÉ¥¹œÕ¹¥Ğ€ôÉ•ÅÕ•ÍĞ¹Õ¹¥Ğ ¤€ôô¹Õ±°€ü‰…Ñ ¹•ÑU¹¥Ğ ¤€èÉ•ÅÕ•ÍĞ¹Õ¹¥Ğ ¤ì(€€€€€€€1½…±…Ñ”ÁÉ½‘ÕÑ¥½¹…Ñ”€ôÉ•ÅÕ•ÍĞ¹ÁÉ½‘ÕÑ¥½¹…Ñ” ¤€ôô¹Õ±°€ü‰…Ñ ¹•ÑAÉ½‘ÕÑ¥½¹…Ñ” ¤€èÉ•ÅÕ•ÍĞ¹ÁÉ½‘ÕÑ¥½¹…Ñ” ¤ì(€€€€€€€%¹Ñ••ÈÍ¡•±™1¥™•Y…±Õ”€ôÉ•ÅÕ•ÍĞ¹Í¡•±™1¥™•Y…±Õ” ¤€ôô¹Õ±°€ü‰…Ñ ¹•ÑM¡•±™1¥™•Y…±Õ” ¤€èÉ•ÅÕ•ÍĞ¹Í¡•±™1¥™•Y…±Õ” ¤ì(€€€€€€€Ù…ÈÍ¡•±™1¥™•U¹¥Ğ€ôÉ•ÅÕ•ÍĞ¹Í¡•±™1¥™•U¹¥Ğ ¤€ôô¹Õ±°€ü‰…Ñ ¹•ÑM¡•±™1¥™•U¹¥Ğ ¤€èÉ•ÅÕ•ÍĞ¹Í¡•±™1¥™•U¹¥Ğ ¤ì(€€€€€€€1½…±…Ñ”•áÁ¥Éå…Ñ”€ôÉ•ÅÕ•ÍĞ¹•áÁ¥Éå…Ñ” ¤ì(€€€€€€€¥˜€¡•áÁ¥Éå…Ñ”€ôô¹Õ±°¤ì(€€€€€€€€€€€•áÁ¥Éå…Ñ”€ô‰…Ñ ¹•ÑáÁ¥Éå…Ñ” ¤ì(€€€€€€€€€€€¥˜€¡É•ÅÕ•ÍĞ¹ÁÉ½‘ÕÑ¥½¹…Ñ” ¤€„ô¹Õ±°ñğÉ•ÅÕ•ÍĞ¹Í¡•±™1¥™•Y…±Õ” ¤€„ô¹Õ±°ñğÉ•ÅÕ•ÍĞ¹Í¡•±™1¥™•U¹¥Ğ ¤€„ô¹Õ±°¤ì(€€€€€€€€€€€€€€€1½…±…Ñ”‘•É¥Ù•€ô•áÁ¥ÉåM•ÉÙ¥”¹‘•É¥Ù•áÁ¥Éå…Ñ”¡ÁÉ½‘ÕÑ¥½¹…Ñ”°Í¡•±™1¥™•Y…±Õ”°Í¡•±™1¥™•U¹¥Ğ¤ì(€€€€€€€€€€€€€€€¥˜€¡‘•É¥Ù•€„ô¹Õ±°¤•áÁ¥Éå…Ñ”€ô‘•É¥Ù•ì(€€€€€€€€€€€ô(€€€€€€€ô(€€€€€€€1½…±…Ñ”½Á•¹•‘…Ñ”€ôÉ•ÅÕ•ÍĞ¹½Á•¹•‘…Ñ” ¤€ôô¹Õ±°€ü‰…Ñ ¹•Ñ=Á•¹•‘…Ñ” ¤€èÉ•ÅÕ•ÍĞ¹½Á•¹•‘…Ñ” ¤ì(€€€€€€€%¹Ñ••È…™Ñ•É=Á•¹Y…±Õ”€ôÉ•ÅÕ•ÍĞ¹…™Ñ•É=Á•¹Y…±Õ” ¤€ôô¹Õ±°€ü‰…Ñ ¹•Ñ™Ñ•É=Á•¹Y…±Õ” ¤€èÉ•ÅÕ•ÍĞ¹…™Ñ•É=Á•¹Y…±Õ” ¤ì(€€€€€€€Ù…È…™Ñ•É=Á•¹U¹¥Ğ€ôÉ•ÅÕ•ÍĞ¹…™Ñ•É=Á•¹U¹¥Ğ ¤€ôô¹Õ±°€ü‰…Ñ ¹•Ñ™Ñ•É=Á•¹U¹¥Ğ ¤€èÉ•ÅÕ•ÍĞ¹…™Ñ•É=Á•¹U¹¥Ğ ¤ì((€€€€€€€‰…Ñ ¹ÕÁ‘…Ñ”¡ÅÕ…¹Ñ¥Ñä°Õ¹¥Ğ°ÁÉ½‘ÕÑ¥½¹…Ñ”°•áÁ¥Éå…Ñ”°Í¡•±™1¥™•Y…±Õ”°Í¡•±™1¥™•U¹¥Ğ°(€€€€€€€€€€€½Á•¹•‘…Ñ”°…™Ñ•É=Á•¹Y…±Õ”°…™Ñ•É=Á•¹U¹¥Ğ°¹½Ü¤ì(€€€€€€€É•ÑÕÉ¸Ñ½I•ÍÁ½¹Í”¡¥Ñ•´°‰…Ñ ¤ì(€€€ô((€€€QÉ…¹Í…Ñ¥½¹…°(€€€ÁÕ‰±¥ŒÙ½¥‘•±•Ñ”¡MÑÉ¥¹œ¥¤ì(€€€€€€€%Ñ•µ¹Ñ¥Ñä¥Ñ•´€ô™¥¹‘%Ñ•´¡¥¤ì(€€€€€€€¥Ñ•´¹Í½™Ñ•±•Ñ”¡%¹ÍÑ…¹Ğ¹¹½Ü¡±½¬¤¤ì(€€€ô((€€€ÁÉ¥Ù…Ñ”%Ñ•µI•ÍÁ½¹Í”Ñ½I•ÍÁ½¹Í”¡%Ñ•µ¹Ñ¥Ñä¥Ñ•´°%¹Ù•¹Ñ½Éå	…Ñ¡¹Ñ¥Ñä‰…Ñ ¤ì(€€€€€€€áÁ¥ÉåÙ…±Õ…Ñ¥½¸•Ù…±Õ…Ñ¥½¸€ô•áÁ¥ÉåM•ÉÙ¥”¹•Ù…±Õ…Ñ” (€€€€€€€€€€€‰…Ñ ¹•ÑáÁ¥Éå…Ñ” ¤°‰…Ñ ¹•Ñ=Á•¹•‘…Ñ” ¤°‰…Ñ ¹•Ñ™Ñ•É=Á•¹Y…±Õ” ¤°‰…Ñ ¹•Ñ™Ñ•É=Á•¹U¹¥Ğ ¤°(€€€€€€€€€€€U1Q}I5%9I}eL°1½…±…Ñ”¹¹½Ü¡±½¬¤(€€€€€€€€¤ì(€€€€€€€É•ÑÕÉ¸¹•Ü%Ñ•µI•ÍÁ½¹Í” (€€€€€€€€€€€¥Ñ•´¹•Ñ% ¤°¥Ñ•´¹•Ñ9…µ” ¤°¥Ñ•´¹•Ñ…Ñ•½Éå% ¤°¥Ñ•´¹•Ñ	É…¹ ¤°¥Ñ•´¹•Ñ1¥™•å±•MÑ…ÑÕÌ ¤°(€€€€€€€€€€€‰…Ñ ¹•ÑEÕ…¹Ñ¥Ñä ¤°‰…Ñ ¹•ÑU¹¥Ğ ¤°‰…Ñ ¹•ÑAÉ½‘ÕÑ¥½¹…Ñ” ¤°‰…Ñ ¹•ÑáÁ¥Éå…Ñ” ¤°(€€€€€€€€€€€•Ù…±Õ…Ñ¥½¸¹•™™•Ñ¥Ù•áÁ¥Éå…Ñ” ¤°•Ù…±Õ…Ñ¥½¸¹É•µ…¥¹¥¹…åÌ ¤°•Ù…±Õ…Ñ¥½¸¹ÍÑ…ÑÕÌ ¤°(€€€€€€€€€€€¥Ñ•´¹•ÑÉ•…Ñ•‘Ğ ¤°¥Ñ•´¹•ÑUÁ‘…Ñ•‘Ğ ¤(€€€€€€€€¤ì(€€€ô((€€€ÁÉ¥Ù…Ñ”%Ñ•µ¹Ñ¥Ñä™¥¹‘%Ñ•´¡MÑÉ¥¹œ¥¤ì(€€€€€€€É•ÑÕÉ¸¥Ñ•µI•Á½Í¥Ñ½Éä¹™¥¹‘	å%‘¹‘•±•Ñ•‘Ñ9Õ±°¡¥¤(€€€€€€€€€€€€¹½É±Í•Q¡É½Ü  ¤€´ø¹•Ü	ÕÍ¥¹•ÍÍá•ÁÑ¥½¸ ÌÀÀÀÀÄ°€‰¥Ñ•´¹½Ğ™½Õ¹ˆ¤¤ì(€€€ô((€€€ÁÉ¥Ù…Ñ”%¹Ù•¹Ñ½Éå	…Ñ¡¹Ñ¥Ñä™¥¹‘	…Ñ ¡MÑÉ¥¹œ¥Ñ•µ%¤ì(€€€€€€€É•ÑÕÉ¸‰…Ñ¡I•Á½Í¥Ñ½Éä¹™¥¹‘¥ÉÍÑ	å%Ñ•µ%‘=É‘•É	åÉ•…Ñ•‘ÑÍŒ¡¥Ñ•µ%¤(€€€€€€€€€€€€¹½É±Í•Q¡É½Ü  ¤€´ø¹•Ü	ÕÍ¥¹•ÍÍá•ÁÑ¥½¸ ÌÀÀÀÀÈ°€‰¥¹Ù•¹Ñ½Éä‰…Ñ ¹½Ğ™½Õ¹ˆ¤¤ì(€€€ô((€€€ÁÉ¥Ù…Ñ”Ù½¥É•ÅÕ¥É•…Ñ•½Éä¡MÑÉ¥¹œ…Ñ•½Éå%¤ì(€€€€€€€¥˜€ ……Ñ•½ÉåI•Á½Í¥Ñ½Éä¹•á¥ÍÑÍ	å%¡…Ñ•½Éå%¤¤ì(€€€€€€€€€€€Ñ¡É½Ü¹•Ü	ÕÍ¥¹•ÍÍá•ÁÑ¥½¸ ÌÀÀÀÀÌ°€‰…Ñ•½Éä¹½Ğ™½Õ¹ˆ¤ì(€€€€€€€ô(€€€ô((€€€ÁÉ¥Ù…Ñ”Ù½¥Ù…±¥‘…Ñ•M¡•±™1¥™”¡1½…±…Ñ”ÁÉ½‘ÕÑ¥½¹…Ñ”°1½…±…Ñ”•áÁ¥Éå…Ñ”°%¹Ñ••ÈÙ…±Õ”°(€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€€½´¹Íµ…ÉÑ•áÁ¥Éä¹•áÁ¥Éä¹‘½µ…¥¸¹M¡•±™1¥™•U¹¥ĞÕ¹¥Ğ¤ì(€€€€€€€¥˜€¡•áÁ¥Éå…Ñ”€ôô¹Õ±°€˜˜€„¡ÁÉ½‘ÕÑ¥½¹…Ñ”€„ô¹Õ±°€˜˜Ù…±Õ”€„ô¹Õ±°€˜˜Õ¹¥Ğ€„ô¹Õ±°¤¤ì(€€€€€€€€€€€Ñ¡É½Ü¹•Ü	ÕÍ¥¹•ÍÍá•ÁÑ¥½¸ ÌÀÀÀÀĞ°(€€€€€€€€€€€€€€€€‰•áÁ¥Éå…Ñ”½ÈÁÉ½‘ÕÑ¥½¹…Ñ”­Í¡•±™1¥™•Y…±Õ”­Í¡•±™1¥™•U¹¥Ğ¥ÌÉ•ÅÕ¥É•ˆ¤ì(€€€€€€€ô(€€€ô)ô(