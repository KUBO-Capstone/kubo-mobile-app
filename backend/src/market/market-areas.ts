// Where to put Market Watch pins. DA only gives market NAMES, so coordinates
// are maintained here by hand.
//
// Coordinates are approximate (the market's neighbourhood, good to a few
// hundred metres) - enough to place a pin on a city map, not for navigation.
// Markets not listed here still import; they just get no pin and the map
// falls back to the region's centroid pin.

export interface MarketArea {
    city: string;
    latitude: number;
    longitude: number;
}

// Region centroid used for the 'region' aggregate row (regional capital or
// the region's economic centre).
export const REGION_CENTROIDS: Record<string, { latitude: number; longitude: number }> = {
    'Region I': { latitude: 16.6159, longitude: 120.3166 },      // San Fernando, La Union
    'Region II': { latitude: 17.6132, longitude: 121.7270 },     // Tuguegarao
    'Region III': { latitude: 15.0286, longitude: 120.6898 },    // San Fernando, Pampanga
    'Region IV-A': { latitude: 14.2117, longitude: 121.1653 },   // Calamba
    'Region IV-B': { latitude: 13.4117, longitude: 121.1803 },   // Calapan
    'Region V': { latitude: 13.1391, longitude: 123.7438 },      // Legazpi
    'Region VI': { latitude: 10.7202, longitude: 122.5621 },     // Iloilo City
    'Region VII': { latitude: 10.3157, longitude: 123.8854 },    // Cebu City
    'Region VIII': { latitude: 11.2443, longitude: 125.0038 },   // Tacloban
    'Region IX': { latitude: 7.8257, longitude: 123.4370 },      // Pagadian
    'Region X': { latitude: 8.4542, longitude: 124.6319 },       // Cagayan de Oro
    'Region XI': { latitude: 7.1907, longitude: 125.4553 },      // Davao City
    'Region XII': { latitude: 6.5031, longitude: 124.8469 },     // Koronadal
    'Region XIII': { latitude: 8.9475, longitude: 125.5406 },    // Butuan
    'NCR': { latitude: 14.5995, longitude: 120.9842 },           // Manila
    'CAR': { latitude: 16.4023, longitude: 120.5960 },           // Baguio
    'BARMM': { latitude: 7.2236, longitude: 124.2464 },          // Cotabato City
};

// Keyed by the market name exactly as DA's header prints it (upper case).
// NCR's 38 markets as of 2026-09; other regions have none yet and fall back
// to the region pin - add them here as they matter to the demo.
export const MARKET_AREAS: Record<string, MarketArea> = {
    'COMMONWEALTH MARKET': { city: 'Quezon City', latitude: 14.6965, longitude: 121.0845 },
    'GUADALUPE PUBLIC MARKET': { city: 'Makati', latitude: 14.5662, longitude: 121.0460 },
    'NEW LAS PINAS CITY PUBLIC MARKET': { city: 'Las Piñas', latitude: 14.4547, longitude: 120.9827 },
    'MARIKINA PUBLIC MARKET': { city: 'Marikina', latitude: 14.6320, longitude: 121.0964 },
    'MUNOZ MARKET': { city: 'Quezon City', latitude: 14.6575, longitude: 121.0207 },
    'PASAY CITY MARKET': { city: 'Pasay', latitude: 14.5442, longitude: 120.9997 },
    'MUTYA NG PASIG MEGA MARKET': { city: 'Pasig', latitude: 14.5736, longitude: 121.0826 },
    'QUINTA MARKET': { city: 'Manila', latitude: 14.5993, longitude: 120.9818 },
    'SAN ANDRES MARKET': { city: 'Manila', latitude: 14.5730, longitude: 120.9968 },
    'MEGA Q MART': { city: 'Quezon City', latitude: 14.6213, longitude: 121.0550 },
    'PAMILIHANG LUNGSOD NG MUNTINLUPA': { city: 'Muntinlupa', latitude: 14.3829, longitude: 121.0452 },
    'MALABON CENTRAL MARKET': { city: 'Malabon', latitude: 14.6622, longitude: 120.9569 },
    'PRITIL MARKET': { city: 'Manila', latitude: 14.6180, longitude: 120.9682 },
    'MAYPAJO PUBLIC MARKET': { city: 'Caloocan', latitude: 14.6401, longitude: 120.9748 },
    'PACO MARKET': { city: 'Manila', latitude: 14.5828, longitude: 120.9905 },
    'DAGONOY MARKET': { city: 'Manila', latitude: 14.5757, longitude: 120.9910 },
    'TRABAJO MARKET': { city: 'Manila', latitude: 14.6072, longitude: 120.9922 },
    'BLUMENTRITT MARKET': { city: 'Manila', latitude: 14.6224, longitude: 120.9847 },
    'MANDALUYONG PUBLIC MARKET I': { city: 'Mandaluyong', latitude: 14.5832, longitude: 121.0330 },
    'MANDALUYONG PUBLIC MARKET II': { city: 'Mandaluyong', latitude: 14.5790, longitude: 121.0390 },
    'NAVOTAS AGORA MARKET': { city: 'Navotas', latitude: 14.6541, longitude: 120.9458 },
    'LA HUERTA MARKET': { city: 'Parañaque', latitude: 14.4975, longitude: 120.9871 },
    'CARTIMAR MARKET': { city: 'Pasay', latitude: 14.5511, longitude: 121.0007 },
    'GRACE MARKETPLACE (PATEROS)': { city: 'Pateros', latitude: 14.5437, longitude: 121.0663 },
    'MURPHY MARKET': { city: 'Quezon City', latitude: 14.6163, longitude: 121.0562 },
    'KAMUNING MARKET': { city: 'Quezon City', latitude: 14.6280, longitude: 121.0378 },
    'AGORA PUBLIC MARKET (SAN JUAN)': { city: 'San Juan', latitude: 14.6025, longitude: 121.0323 },
    'BICUTAN MARKET': { city: 'Taguig', latitude: 14.4864, longitude: 121.0453 },
    "TAGUIG PEOPLE'S MARKET": { city: 'Taguig', latitude: 14.5278, longitude: 121.0724 },
    'NEW MARULAS PUBLIC MARKET': { city: 'Valenzuela', latitude: 14.6889, longitude: 120.9803 },
    'BALINTAWAK MARKET (CLOVERLEAF)': { city: 'Quezon City', latitude: 14.6572, longitude: 121.0006 },
    'FARMERS MARKET': { city: 'Quezon City', latitude: 14.6193, longitude: 121.0530 },
    'HULONG DUHAT PUBLIC MARKET': { city: 'Malabon', latitude: 14.6706, longitude: 120.9532 },
    'KMLV NEW KARUHATAN MARKET': { city: 'Valenzuela', latitude: 14.6910, longitude: 120.9730 },
    'NEW PARANG MARKET': { city: 'Marikina', latitude: 14.6535, longitude: 121.1045 },
    'NORTH DIVERSION MARKET': { city: 'Caloocan', latitude: 14.6540, longitude: 120.9986 },
    'POBLACION PUBLIC MARKET': { city: 'Makati', latitude: 14.5643, longitude: 121.0318 },
    'SUKI MARKET': { city: 'Quezon City', latitude: 14.6605, longitude: 121.0455 },
};

// Title-cases DA's shouting header ("MUTYA NG PASIG MEGA MARKET" ->
// "Mutya ng Pasig Mega Market") for display; the lookup above stays upper.
export function displayMarketName(raw: string): string {
    const small = new Set(['ng', 'of', 'de', 'sa', 'at', 'the']);
    return raw
        .toLowerCase()
        .split(' ')
        .map((word, i) => (i > 0 && small.has(word) ? word : word.replace(/(^|[(\-'])([a-z])/g, (_, p, c) => p + c.toUpperCase())))
        .join(' ');
}
