 enum InputUnit { meter, unit }

class SpecialComponentConfig {
  final int productId;
  final String title;
  final List<double> factors;
  final double secondFactor;
  final double divisor;
  final InputUnit inputUnit;

  const SpecialComponentConfig({
    required this.productId,
    required this.title,
    required this.factors,
    required this.secondFactor,
    this.divisor = 10000,
    this.inputUnit = InputUnit.unit,
  });

  String get unitSuffix => inputUnit == InputUnit.meter ? "m" : "u";
}

class SpecialComponentsRegistry {
  static const List<SpecialComponentConfig> configs = [
    SpecialComponentConfig(
      productId: 20238,
      title: "Bois 10 x 1.9",
      factors: [10, 7, 5, 3],
      secondFactor: 1.9,
      inputUnit: InputUnit.meter,
    ),
    SpecialComponentConfig(
      productId: 20237,
      title: "Bois 10 x 2.5",
      factors: [10, 7, 5, 3],
      secondFactor: 2.5,
      inputUnit: InputUnit.meter,
    ),
    SpecialComponentConfig(
      productId: 31987,
      title: "Bois 17.5 x 2.5",
      factors: [17.5],
      secondFactor: 2.5,
      inputUnit: InputUnit.meter,
    ),
    SpecialComponentConfig(
      productId: 26395,
      title: "Bois 5 x 15",
      factors: [5],
      secondFactor: 15,
      inputUnit: InputUnit.meter,
    ),

    SpecialComponentConfig(
      productId: 24985,
      title: "Contre Plaqué 2.5 x 1.25",
      factors: [2.5],
      secondFactor: 1.25,
      divisor: 1,
      inputUnit: InputUnit.unit,
    ),
    SpecialComponentConfig(
      productId: 24984,
      title: "Contre Plaqué 2.5 x 1.85",
      factors: [2.5],
      secondFactor: 1.85,
      divisor: 1,
      inputUnit: InputUnit.unit,
    ),
    SpecialComponentConfig(
      productId: 24986,
      title: "Contre Plaqué 2.5 x 1.85",
      factors: [2.5],
      secondFactor: 1.85,
      divisor: 1,
      inputUnit: InputUnit.unit,
    ),
    SpecialComponentConfig(
      productId: 20336,
      title: "Contre Plaqué 2.5 x 1.25",
      factors: [2.5],
      secondFactor: 1.25,
      divisor: 1,
      inputUnit: InputUnit.unit,
    ),
    SpecialComponentConfig(
      productId: 20335,
      title: "Bois Blanc 20 x 6",
      factors: [20],
      secondFactor: 6,
      divisor: 10000,
      inputUnit: InputUnit.unit,
    ),
    SpecialComponentConfig(
      productId: 20327,
      title: "MDF Brute 2.5 x 1.85",
      factors: [2.5],
      secondFactor: 1.85,
      divisor: 1,
      inputUnit: InputUnit.unit,
    ),
    SpecialComponentConfig(
      productId: 20329,
      title: "MDF Brute 2.8 x 2.1",
      factors: [2.8],
      secondFactor: 2.1,
      divisor: 1,
      inputUnit: InputUnit.unit,
    ),
    SpecialComponentConfig(
      productId: 20330,
      title: "MDF Brute 2.8 x 2.1",
      factors: [2.8],
      secondFactor: 2.1,
      divisor: 1,
      inputUnit: InputUnit.unit,
    ),
    SpecialComponentConfig(
      productId: 20331,
      title: "MDF Stratifié 2.8 x 2.1",
      factors: [2.8],
      secondFactor: 2.1,
      divisor: 1,
      inputUnit: InputUnit.unit,
    ),
    SpecialComponentConfig(
      productId: 20332,
      title: "MDF Stratifié 2.8 x 2.1",
      factors: [2.8],
      secondFactor: 2.1,
      divisor: 1,
      inputUnit: InputUnit.unit,
    ),
    SpecialComponentConfig(
      productId: 25286,
      title: "MDF Stratifié 2.8 x 2.1",
      factors: [2.8],
      secondFactor: 2.1,
      divisor: 1,
      inputUnit: InputUnit.unit,
    ),
    SpecialComponentConfig(
      productId: 25287,
      title: "MDF Stratifié 2.8 x 2.1",
      factors: [2.8],
      secondFactor: 2.1,
      divisor: 1,
      inputUnit: InputUnit.unit,
    ),
    SpecialComponentConfig(
      productId: 26619,
      title: "MDF Stratifié 2.8 x 2.1",
      factors: [2.8],
      secondFactor: 2.1,
      divisor: 1,
      inputUnit: InputUnit.unit,
    ),
    SpecialComponentConfig(
      productId: 44404,
      title: "MDF Stratifié 2.8 x 2.1",
      factors: [2.8],
      secondFactor: 2.1,
      divisor: 1,
      inputUnit: InputUnit.unit,
    ),
    SpecialComponentConfig(
      productId: 38309,
      title: "MDF Particule 2.8 x 2.1",
      factors: [2.8],
      secondFactor: 2.1,
      divisor: 1,
      inputUnit: InputUnit.unit,
    ),
    SpecialComponentConfig(
      productId: 38310,
      title: "MDF Particule 2.8 x 2.1",
      factors: [2.8],
      secondFactor: 2.1,
      divisor: 1,
      inputUnit: InputUnit.unit,
    ),
    SpecialComponentConfig(
      productId: 38313,
      title: "MDF Particule 2.8 x 2.1",
      factors: [2.8],
      secondFactor: 2.1,
      divisor: 1,
      inputUnit: InputUnit.unit,
    ),
    SpecialComponentConfig(
      productId: 20926,
      title: "Salba 1.5 x 1",
      factors: [1.5],
      secondFactor: 1,
      divisor: 1,
      inputUnit: InputUnit.unit,
    ),
  ];

  static SpecialComponentConfig? find(int productId) {
    for (final c in configs) {
      if (c.productId == productId) return c;
    }
    return null;
  }


}
 class SimpleM2ComponentMatcher {
   static bool matches(String productName) {
     final cleaned = productName
         .replaceFirst(RegExp(r'^\[.*?\]\s*'), '')
         .trim()
         .toUpperCase();
     return cleaned.contains("MDF") || cleaned.contains("PLAQU");
   }
 }