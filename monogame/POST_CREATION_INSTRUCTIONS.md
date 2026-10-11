# Post-Creation Instructions

If you encountered "workload not installed" errors when creating the MonoGame project, follow the steps below to resolve the dependencies and run your game.

## 1. Install .NET Workloads

These commands install the necessary packages to develop for Android, iOS, and WebAssembly:

```bash
dotnet workload install android
dotnet workload install ios
dotnet workload install wasm-tools
```

_(Note: The iOS workload requires that you are on macOS with Xcode installed)._

## 2. Restore Projects

With the workloads installed, navigate to the project folder (if you are not already in it) and restore dependencies:

```bash
cd MyGame
dotnet restore
```

## 3. Run the Game (Desktop)

To quickly test your game in the desktop version, run the command below while inside the `MyGame` folder:

```bash
dotnet run --project MyGame.Desktop
```

## 4. Run the Game (Android)

To run the project on Android (make sure you have a running emulator or configured connected device):

```bash
dotnet build MyGame.Android -t:Run
```

_(Note: The `dotnet run` command may require additional configurations depending on the emulator; if you encounter errors, opening the project via Visual Studio or Rider/VS Code is usually the easiest, or use `dotnet build -t:Run`)._

## 5. Run the Game (iOS)

To run the project on iOS (make sure you have a simulator or device configured via Xcode):

```bash
dotnet build MyGame.iOS -t:Run
```

## 6. Run the Game (Browser / WebAssembly)

To compile and play directly in the browser using WebAssembly:

```bash
dotnet run --project MyGame.Browser
```

To generate the final files ready for production (Release), run:

```bash
dotnet publish MyGame.Browser -c Release
```
