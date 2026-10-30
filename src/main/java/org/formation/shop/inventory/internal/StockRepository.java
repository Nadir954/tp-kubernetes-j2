package org.formation.shop.inventory.internal;

import org.springframework.data.jpa.repository.JpaRepository;

public interface StockRepository extends JpaRepository<StockEntity, Long> {
    java.util.Optional<StockEntity> findByCoffeeId(Long coffeeId);
}
