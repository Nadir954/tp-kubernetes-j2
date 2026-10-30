package org.formation.shop.catalog;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/coffees")
class CatalogController {
    private final Catalog catalog;

    CatalogController(Catalog catalog) { this.catalog = catalog; }

    @org.springframework.web.bind.annotation.GetMapping
    java.util.List<Catalog.CoffeeView> all() { return catalog.findAll(); }

    @PostMapping
    Long create(@RequestParam String name, @RequestParam int price) {
        return catalog.createCoffee(name, price);
    }
}
