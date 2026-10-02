# M1 Validation Report

Validation performed in the generation environment:

- `shared/expiry-test-cases.json`: JSON parse passed.
- `openapi/smart-expiry-v1.yaml`: YAML/OpenAPI structural parse passed.
- HarmonyOS `.json5` project files: strict JSON parse passed.
- Maven `pom.xml`: XML parse passed.
- Java `ExpiryService` and related domain classes: compiled with JDK 21 and executed against all shared expiry fixtures.
- ArkTS `ExpiryService.ets`: TypeScript-compatible domain code compiled with `tsc 5.8.3` and executed with Node 22 against the same fixtures.
- Shared contract result: **9/9 cases passed on both implementations**, including month-end and leap-year clamp behavior.
- Generated ArkTS fixture synchronization check passed.
- Basic OpenAPI/controller route consistency check passed.
- Secret-pattern scan passed.

## Environment limitation

The generation sandbox does not have Docker or Maven preinstalled and outbound DNS from the container is blocked. Therefore the complete Spring dependency graph could not be downloaded and `mvn test` could not be executed inside this sandbox.

The repo includes a Maven bootstrap script (`backend/mvnw`) and CI workflow. In a normal development/CI environment with internet access, run:

```bash
cd backend
./mvnw test
```

The HarmonyOS project also requires DevEco Studio/HarmonyOS SDK, which is not available in this sandbox. Import `harmonyos/` into DevEco Studio and run the `entry` module plus `ohosTest` target.
