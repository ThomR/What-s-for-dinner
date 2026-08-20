import Testing
import Foundation

/// Opslag en uitwisseling: wat bewaard of gedeeld wordt moet er ongeschonden
/// weer uitkomen, ook uit een bestand van de vorige versie.
@Suite("Opslag en delen")
struct OpslagTests {

    @Test("Een planning overleeft coderen en decoderen")
    func planningRondreis() throws {
        let origineel = MealPlan(
            dishes: [gerecht("Pizza", emoji: "🍕"), gerecht("Soep", emoji: "🍲")],
            anchorDate: testCalendar.startOfDay(for: datum(2026, 8, 20)),
            log: [ServedMeal(dish: gerecht("Pasta"), servedOn: datum(2026, 8, 19))]
        )
        let data = try JSONEncoder.plan.encode(origineel)
        let terug = try JSONDecoder.plan.decode(MealPlan.self, from: data)
        #expect(terug == origineel)
    }

    @Test("Datums staan als leesbare tekst in het bestand")
    func datumsAlsTekst() throws {
        let plan = planning(vanaf: datum(2026, 8, 20), "Pizza")
        let json = String(data: try JSONEncoder.plan.encode(plan), encoding: .utf8) ?? ""
        #expect(json.contains("2026-08-"), "verwachtte een ISO-datum, kreeg: \(json)")
    }

    @Test("Een gedeelde lijst komt er hetzelfde weer uit")
    func exportRondreis() throws {
        let dishes = [gerecht("Pizza", emoji: "🍕"), gerecht("Soep", emoji: "🍲")]
        let data = try JSONEncoder.plan.encode(dishes)
        let terug = DishListExport.read(data)
        #expect(terug?.map(\.name) == ["Pizza", "Soep"])
        #expect(terug?.map(\.emoji) == ["🍕", "🍲"])
    }

    @Test("Een lijst uit versie 1 wordt nog gelezen")
    func oudeLijstLezen() throws {
        // Versie 1 schreef geen addedAt en gebruikte een getal voor completedDate.
        let oud = """
        [{"id":"0E4B8B54-2C6B-4E5E-9B0E-6F7A9F1E2D3C","name":"Pizza","emoji":"🍕","completedDate":null},
         {"id":"1E4B8B54-2C6B-4E5E-9B0E-6F7A9F1E2D3C","name":"Soep","emoji":"🍲"}]
        """
        let dishes = DishListExport.read(Data(oud.utf8))
        #expect(dishes?.map(\.name) == ["Pizza", "Soep"])
    }

    @Test("Onzin levert niets op in plaats van een halve lijst")
    func onleesbareInvoer() {
        #expect(DishListExport.read(Data("dit is geen json".utf8)) == nil)
        #expect(DishListExport.read(Data("[]".utf8)) == nil)
    }

    @Test("Een gerecht houdt zijn identiteit bij het terugzetten uit het logboek")
    func herstellenBehoudtIdentiteit() {
        let dish = gerecht("Pizza", emoji: "🍕")
        let gegeten = ServedMeal(dish: dish, servedOn: datum(2026, 8, 19))
        let terug = gegeten.restored(at: datum(2026, 8, 20))
        #expect(terug.id == dish.id)
        #expect(terug.name == "Pizza")
        #expect(terug.emoji == "🍕")
    }

    @Test("De eerste emoji is bruikbaar voor de complicatie")
    func eersteEmoji() {
        #expect(Dish(name: "Kip met rijst", emoji: "🍗 🍚").primaryEmoji == "🍗")
        #expect(Dish(name: "Pizza", emoji: "🍕").primaryEmoji == "🍕")
        #expect(Dish(name: "Onbekend", emoji: "").primaryEmoji == Emoji.fallback)
    }
}
