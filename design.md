# YatraCanvas CityPack Lab design direction

**Source:** product audit and the existing Flutter Material 3 implementation.

The product serves city data contributors and release managers who need confidence more than decoration. The character is editorial, grounded, and decisive, like a field notebook prepared for a release room.

Use warm paper backgrounds, white raised work surfaces, deep teal structure, saffron attention, and red only for true blockers. Typography is system native with strong sentence case headings and generous line height. Layouts use a constrained reading width, a navigation rail on desktop, bottom navigation on narrow screens, and cards only when they group a real task or decision.

The signature element is the release runway. It presents Fix, Review, and Release as one numbered path with visible current state and remaining work. Motion should communicate progress or a state change only.

Token values live in `lib/app/lab_theme.dart`. New UI should use those tokens and `Theme.of(context)` rather than introduce isolated color or spacing literals.
