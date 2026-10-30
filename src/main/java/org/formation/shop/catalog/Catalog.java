package org.formation.shop.catalog;

import org.formation.shop.catalog.internal.CoffeeEntity;
import org.formation.shop.catalog.internal.CoffeeRepository;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class Catalog {
    @Transactional(readOnly = true)
    public java.util.List<CoffeeView> findAll() {
        return repository.findAll().stream().map(c -> new CoffeeView(c.getId(), c.getName(), c.getPrice())).toList();
    }

    public record CoffeeView(Long id, String name, int price) {}

    private final CoffeeRepository repository;
    private final ApplicationEventPublisher events;

    public Catalog(CoffeeRepository repository, ApplicationEventPublisher events) {
        this.repository = repository;
        this.events = events;
    }

    @Transactional
    public Long createCoffee(String name, int price) {
        CoffeeEntity saved = repository.save(new CoffeeEntity(name, price));
        events.publishEvent(new CoffeeCreated(saved.getId(), saved.getName()));
        return saved.getId();
    }
}
