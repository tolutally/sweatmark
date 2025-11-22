const String BODY_FRONT_SVG = '''
<svg viewBox="0 0 200 450" xmlns="http://www.w3.org/2000/svg" class="w-full h-full drop-shadow-lg">
    <defs>
        <style>
            .muscle { stroke: #1f2937; stroke-width: 1px; transition: fill 0.3s ease; }
            .muscle:hover { opacity: 0.9; }
        </style>
    </defs>

    <!-- Head & Neck (Static) -->
    <circle cx="100" cy="35" r="15" fill="#4B5563" />
    <path d="M92,50 L108,50 L108,60 L92,60 Z" fill="#4B5563" />

    <!-- Shoulders (Deltoids) -->
    <!-- Left -->
    <path id="muscle-shoulders-left" class="muscle fill-gray-700" d="M60,65 Q75,60 92,62 L92,80 L65,85 Z" />
    <!-- Right -->
    <path id="muscle-shoulders-right" class="muscle fill-gray-700" d="M140,65 Q125,60 108,62 L108,80 L135,85 Z" />

    <!-- Chest (Pectorals) -->
    <path id="muscle-chest" class="muscle fill-gray-700" d="M92,80 L108,80 L108,115 L92,115 Z M65,85 L92,80 L92,115 L70,110 Z M135,85 L108,80 L108,115 L130,110 Z" />

    <!-- Biceps -->
    <path id="muscle-biceps" class="muscle fill-gray-700" d="M60,85 L65,85 L70,110 L55,108 Z M140,85 L135,85 L130,110 L145,108 Z" />

    <!-- Forearms -->
    <path id="muscle-forearms" class="muscle fill-gray-700" d="M55,108 L70,110 L65,145 L50,140 Z M145,108 L130,110 L135,145 L150,140 Z" />

    <!-- Abs (Abdominals & Obliques) -->
    <path id="muscle-abs" class="muscle fill-gray-700" d="M70,110 L130,110 L125,165 L75,165 Z" />

    <!-- Quads (Thighs) -->
    <path id="muscle-quads" class="muscle fill-gray-700" d="M75,165 L100,165 L98,240 L70,235 Z M125,165 L100,165 L102,240 L130,235 Z" />

    <!-- Calves (Front/Tibialis) -->
    <path id="muscle-calves" class="muscle fill-gray-700" d="M70,240 L98,240 L95,320 L75,315 Z M130,240 L102,240 L105,320 L125,315 Z" />
</svg>
''';

const String BODY_BACK_SVG = '''
<svg viewBox="0 0 200 450" xmlns="http://www.w3.org/2000/svg" class="w-full h-full drop-shadow-lg">
    <defs>
        <style>
            .muscle { stroke: #1f2937; stroke-width: 1px; transition: fill 0.3s ease; }
            .muscle:hover { opacity: 0.9; }
        </style>
    </defs>

    <!-- Head & Neck (Static) -->
    <circle cx="100" cy="35" r="15" fill="#4B5563" />
    <path d="M92,50 L108,50 L108,60 L92,60 Z" fill="#4B5563" />

    <!-- Traps (Upper Back) -->
    <path id="muscle-traps" class="muscle fill-gray-700" d="M92,60 L108,60 L115,75 L85,75 Z M60,65 L92,60 L85,75 L65,80 Z M140,65 L108,60 L115,75 L135,80 Z" />

    <!-- Lats (Latissimus Dorsi) -->
    <path id="muscle-lats" class="muscle fill-gray-700" d="M65,80 L85,75 L92,130 L75,125 Z M135,80 L115,75 L108,130 L125,125 Z" />

    <!-- Lower Back (Erector Spinae) -->
    <path id="muscle-lower_back" class="muscle fill-gray-700" d="M85,75 L115,75 L108,130 L92,130 Z M92,130 L108,130 L105,150 L95,150 Z" />

    <!-- Triceps -->
    <path id="muscle-triceps" class="muscle fill-gray-700" d="M60,85 L65,85 L70,115 L55,112 Z M140,85 L135,85 L130,115 L145,112 Z" />

    <!-- Glutes -->
    <path id="muscle-glutes" class="muscle fill-gray-700" d="M75,150 L125,150 L125,185 L75,185 Z" />

    <!-- Hamstrings -->
    <path id="muscle-hamstrings" class="muscle fill-gray-700" d="M75,185 L100,185 L98,250 L70,245 Z M125,185 L100,185 L102,250 L130,245 Z" />

    <!-- Calves (Back) -->
    <path id="muscle-calves_back" class="muscle fill-gray-700" d="M70,250 L98,250 L95,320 L75,315 Z M130,250 L102,250 L105,320 L125,315 Z" />
</svg>
''';

const Map<String, List<String>> MUSCLE_MAP = {
    'Chest': ['muscle-chest'],
    'Lats': ['muscle-lats'],
    'Lower Back': ['muscle-lower_back'],
    'Quads': ['muscle-quads'],
    'Hamstrings': ['muscle-hamstrings'],
    'Calves': ['muscle-calves', 'muscle-calves_back'],
    'Shoulders': ['muscle-shoulders-left', 'muscle-shoulders-right'],
    'Biceps': ['muscle-biceps'],
    'Triceps': ['muscle-triceps'],
    'Forearms': ['muscle-forearms'],
    'Abs': ['muscle-abs']
};
