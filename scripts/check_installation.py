import argparse

from omni.isaac.lab.app import AppLauncher


def main():
    parser = argparse.ArgumentParser(description="Check installation.")
    AppLauncher.add_app_launcher_args(parser)
    args = parser.parse_args()

    args.headless = True

    launcher = AppLauncher(args)
    app = launcher.app

    print(launcher)
    print(app)

    from omni.isaac.lab.sim import SimulationCfg, SimulationContext

    print(SimulationCfg, SimulationContext)

    app.close()


if __name__ == "__main__":
    main()
