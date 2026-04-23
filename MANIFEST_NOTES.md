# Manifest Handling

`manifest.xml` is a generated Garmin Connect IQ file.

Rules for this project:

- Edit products through the Connect IQ editor commands, not by hand.
- Use `Monkey C: Edit Products` or `Monkey C: Set Products by Product Category`.
- Keep the VS Code build target in `.vscode/tasks.json` aligned with a device that is listed in `manifest.xml`.
- If the manifest is regenerated, re-check that the product list still matches the supported devices.

Current supported products:

- fr165
- fr165m
- fr255
- fr255m
- fr255s
- fr255sm
- fr265
- fr265s
- fr57042mm
- fr57047mm
- fr955
- fr965
- fr970
