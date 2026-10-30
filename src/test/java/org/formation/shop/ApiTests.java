package org.formation.shop;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.jdbc.core.JdbcTemplate;
import java.net.URI;
import java.net.http.*;
import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class ApiTests {
    @LocalServerPort int port;
    @Autowired JdbcTemplate jdbc;
    final HttpClient http = HttpClient.newHttpClient();
    HttpResponse<String> get(String path) throws Exception {
        return http.send(HttpRequest.newBuilder(URI.create("http://localhost:" + port + path)).GET().build(), HttpResponse.BodyHandlers.ofString());
    }
    @Test void createsCoffeeAndStockThroughEventAndExposesHealth() throws Exception {
        var created = http.send(HttpRequest.newBuilder(URI.create("http://localhost:" + port + "/coffees?name=Arabica&price=5")).POST(HttpRequest.BodyPublishers.noBody()).build(), HttpResponse.BodyHandlers.ofString());
        assertThat(created.statusCode()).isEqualTo(200);
        long id = Long.parseLong(created.body());
        var list = get("/coffees");
        assertThat(list.statusCode()).isEqualTo(200);
        assertThat(list.body()).contains("Arabica", "\"price\":5");
        assertThat(get("/stocks/" + id).body()).isEqualTo("0");
        // Vérifier la ligne réelle : un simple HTTP 0 masquerait un listener absent.
        assertThat(jdbc.queryForObject("select count(*) from stock_entity where coffee_id = ? and quantity = 0", Integer.class, id)).isEqualTo(1);
        org.awaitility.Awaitility.await().atMost(java.time.Duration.ofSeconds(10)).untilAsserted(() ->
            assertThat(jdbc.queryForObject("select count(*) from event_publication where completion_date is not null", Integer.class)).isGreaterThanOrEqualTo(1));
        for (String probe : new String[]{"liveness", "readiness"}) {
            var health = get("/actuator/health/" + probe);
            assertThat(health.statusCode()).isEqualTo(200);
            assertThat(health.body()).contains("UP");
        }
    }
}
