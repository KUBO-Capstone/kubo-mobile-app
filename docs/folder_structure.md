kubo-mobile-app/
├── frontend/          # Flutter app
├── backend/           # Node/Express API
├── docs/              # API docs, ERDs, architecture notes
├── .gitignore
└── README.md

frontend/
├── lib/
│   ├── main.dart
│   ├── app.dart                    # MaterialApp/router setup
│   │
│   ├── core/                       # Shared, cross-feature code
│   │   ├── constants/              # API URLs, keys, app-wide constants
│   │   ├── theme/                  # Colors, text styles, ThemeData
│   │   ├── utils/                  # Helpers, formatters, validators
│   │   ├── errors/                 # Custom exceptions, failure classes
│   │   └── network/                # Dio/http client setup, interceptors
│   │
│   ├── data/                       # Data layer
│   │   ├── models/                 # DTOs / JSON serializable models
│   │   ├── repositories/           # Repository implementations
│   │   └── services/               # API service classes (per resource)
│   │
│   ├── domain/                     # (optional, if using clean architecture)
│   │   ├── entities/
│   │   └── repositories/           # Abstract repository interfaces
│   │
│   ├── features/                   # One folder per app feature/screen
│   │   ├── auth/
│   │   │   ├── screens/
│   │   │   ├── widgets/
│   │   │   └── providers/          # or bloc/, controllers/, etc.
│   │   ├── home/
│   │   │   ├── screens/
│   │   │   ├── widgets/
│   │   │   └── providers/
│   │   └── profile/
│   │       ├── screens/
│   │       ├── widgets/
│   │       └── providers/
│   │
│   ├── shared/                     # Reusable widgets across features
│   │   └── widgets/                # Buttons, cards, loaders, etc.
│   │
│   └── routes/                     # go_router / named routes config
│
├── assets/
│   ├── images/
│   ├── icons/
│   └── fonts/
│
├── test/                           # Mirrors lib/ structure
├── pubspec.yaml
└── analysis_options.yaml


backend/
├── src/
│   ├── server.js                   # Entry point (app.listen)
│   ├── app.js                      # Express app setup (middleware, routes)
│   │
│   ├── config/
│   │   ├── db.js                   # Database connection
│   │   ├── env.js                  # Environment variable loader/validator
│   │   └── constants.js
│   │
│   ├── routes/                     # Route definitions per resource
│   │   ├── index.js                # Combines/mounts all routes
│   │   ├── auth.routes.js
│   │   ├── user.routes.js
│   │   └── post.routes.js
│   │
│   ├── controllers/                # Request handlers (thin, call services)
│   │   ├── auth.controller.js
│   │   ├── user.controller.js
│   │   └── post.controller.js
│   │
│   ├── services/                   # Business logic
│   │   ├── auth.service.js
│   │   ├── user.service.js
│   │   └── post.service.js
│   │
│   ├── models/                     # Mongoose/Sequelize/Prisma schemas
│   │   ├── User.js
│   │   └── Post.js
│   │
│   ├── middlewares/
│   │   ├── auth.middleware.js      # JWT verification
│   │   ├── error.middleware.js     # Centralized error handler
│   │   ├── validate.middleware.js  # Request validation (Joi/Zod)
│   │   └── rateLimiter.js
│   │
│   ├── validators/                 # Schema definitions for input validation
│   │   ├── auth.validator.js
│   │   └── user.validator.js
│   │
│   ├── utils/                      # Helpers (logger, response formatter, etc.)
│   │   ├── logger.js
│   │   ├── apiResponse.js
│   │   └── asyncHandler.js
│   │
│   └── sockets/                    # If using WebSockets/Socket.io
│
├── tests/                          # Mirrors src/ structure
│   ├── unit/
│   └── integration/
│
├── .env
├── .env.example
├── package.json
└── nodemon.config.json

docs/
├── folder_structure.md
└── github_flow.md