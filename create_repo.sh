#! /bin/bash

# Create Yarn v2 repository
yarn init -2
# sed -i '' 's/!..yarn.cache//' .gitignore # Do not use zero-installs

# Create `utils` workspace
mkdir -p utils/src && echo "export const addOne = (val: number): number => val + 1" > utils/src/addOne.ts
echo "{}" | jq '.name="@onboarding/utils" | .main="src/addOne.ts"' > utils/package.json

# Create the top level package.json
cat package.json | jq '.workspaces=["frontend", "utils"] | .devDependencies.typescript="=4.4.4" | .name="@onboarding/root"' | sponge package.json

# Create some basic typescript files
echo '{"compilerOptions":{"incremental":true,"target":"es2019","module":"commonjs","lib":["esnext","es2020","es2019","dom"],"allowJs":false,"checkJs":false,"jsx":"react-jsx","declaration":true,"composite":true,"declarationMap":true,"sourceMap":true,"strict":true,"skipLibCheck":true,"noUnusedLocals":true,"noImplicitReturns":true,"noFallthroughCasesInSwitch":true,"moduleResolution":"node","baseUrl":".","types":[],"typeRoots":["@types","node_modules/@types"],"esModuleInterop":true,"resolveJsonModule":true,"forceConsistentCasingInFileNames":true}}' | jq > tsconfig.base.json
echo '{"extends":"../tsconfig.base.json","compilerOptions":{"outDir":"../build/@onboarding/utils","tsBuildInfoFile":"../build/@onboarding/utils.tsbuildinfo","rootDir":"src"}}' | jq > utils/tsconfig.json
echo '{}' | jq '.extends="./tsconfig.base.json" | .include=[] | .files=[] | .references=[{"path": "frontend"},{"path": "utils"}]' > tsconfig.json

# Create a snowpack app
yarn create snowpack-app frontend --template @snowpack/app-template-react-typescript --use-yarn --no-install --no-git
cat frontend/tsconfig.json | yarn dlx --quiet strip-json-comments-cli | jq '.extends="../tsconfig.base.json" | .compilerOptions.noEmit=false' | sponge frontend/tsconfig.json
cat frontend/package.json | yarn dlx --quiet strip-json-comments-cli | jq '.name="@onboarding/frontend" | .devDependencies.typescript="=4.4.4"' | sponge frontend/package.json
yarn workspace @onboarding/frontend add -D @yarnpkg/pnpify
rm frontend/snowpack.config.mjs
cat <<EOT >> frontend/snowpack.config.mjs
/** @type {import("snowpack").SnowpackUserConfig } */
export default {
  workspaceRoot: '..',
  mount: {
    public: { url: '/', static: true },
    src: { url: '/dist' },
  },
  plugins: [
    '@snowpack/plugin-react-refresh',
    '@snowpack/plugin-dotenv',
    [
      '@snowpack/plugin-typescript',
      {
        /* Yarn PnP workaround: see https://www.npmjs.com/package/@snowpack/plugin-typescript */
        ...(process.versions.pnp ? { tsc: 'yarn pnpify tsc' } : {}),
      },
    ],
  ],
};
EOT

# Add an internal dependency
yarn workspace @onboarding/frontend add @onboarding/utils
cat frontend/tsconfig.json | yarn dlx --quiet strip-json-comments-cli | jq '.references=[{"path": "../utils"}]' | sponge frontend/tsconfig.json
echo "import { addOne } from '@onboarding/utils';" | cat - frontend/src/App.tsx | tee frontend/src/App.tsx
sed -i '' 's/count + 1/addOne(count)/' frontend/src/App.tsx 

# Typescript can still build
yarn tsc --build --verbose

# App runs happily :)
# yarn workspace @onboarding/frontend start --open none
