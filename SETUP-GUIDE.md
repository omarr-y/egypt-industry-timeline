# Egypt Industry Timeline: iPhone app setup

This takes about an hour the first time, mostly waiting for Xcode to download. After that, updates are automatic.

What's in this folder:

| File | What it is |
|---|---|
| `EgyptIndustry/*.swift` | The app's code |
| `data/news.json` | The timeline data (143 items as of 6 Oct 2026). It goes to GitHub, and a copy goes inside the app. |
| `build-ipa.sh` | Turns the project into an `.ipa` file that AltStore can install |

How it fits together: **weekly routine → news.json on GitHub → the app downloads it** when you open it or pull down on the list. The app keeps the last copy, so it also works offline.

---

## Step 1. Put the data on GitHub (10 min)

1. Create a free account at github.com if you don't have one.
2. Click **+** (top right) → **New repository**.
   - Name: `egypt-industry-timeline` (exactly this, or the app's link won't match)
   - Visibility: **Public**. The app reads the file without logging in, so it has to be public. It only contains public news summaries.
   - Tick **Add a README file** → **Create repository**.
3. In the new repository, click **Add file → Upload files**, drag in `data/news.json`, and click **Commit changes**.
4. Check it works: open this in your browser, with your username filled in:
   `https://raw.githubusercontent.com/omarr-y/egypt-industry-timeline/main/news.json`
   You should see the JSON text.

## Step 2. Install Xcode (mostly waiting)

1. Open the **App Store** on your Mac, search **Xcode**, and install it (free, large download).
2. Open Xcode once. If it asks which platforms to install, include **iOS**.

## Step 3. Create the project and add the code (10 min)

1. In Xcode: **File → New → Project… → iOS → App → Next**.
2. Fill in:
   - Product Name: `EgyptIndustry` (exactly this, with no space)
   - Team: leave as **None**
   - Organization Identifier: anything, e.g. `com.omar`
   - Interface: **SwiftUI**, Language: **Swift**, Storage/Testing: **None**
3. Save it somewhere easy, e.g. your Desktop.
4. In the left sidebar, inside the yellow `EgyptIndustry` folder, select **ContentView.swift** and **EgyptIndustryApp.swift**, then right-click → **Delete → Move to Trash**. You're replacing them with my versions.
5. From Finder, drag all the `.swift` files from this folder's `EgyptIndustry` folder **and** `data/news.json` onto that yellow `EgyptIndustry` folder in Xcode. In the pop-up, tick **Copy items if needed** and make sure the **EgyptIndustry** target is ticked → **Finish**.
6. **AppConfig.swift** is already set to your GitHub username (`omarr-y`). Change it only if you use a different account.

**Test it on the Mac first:** at the top of Xcode, choose an iPhone simulator (e.g. "iPhone 16") and press **▶ Run** (or ⌘R). The app should open in a simulated iPhone showing the timeline. If you get a red error, copy the message and send it to me.

## Step 4. Build the .ipa file (5 min)

1. Copy `build-ipa.sh` into the project folder you saved in Step 3, the one that contains `EgyptIndustry.xcodeproj`.
2. Open **Terminal** (Applications → Utilities), type `cd ` (with a space), drag that project folder into the Terminal window, and press Enter.
3. Run:
   ```
   bash build-ipa.sh
   ```
4. When it says **Done**, you'll have `EgyptIndustry.ipa` in that folder.

## Step 5. Install AltStore (15 min, one time)

Follow the official guide at **altstore.io** ("Get Started → macOS"). In short:

1. Download and open **AltServer** on your Mac. It appears as a diamond icon in the menu bar.
2. Connect your iPhone with a cable and tap **Trust** on the phone.
3. Menu-bar diamond → **Install AltStore → your iPhone**, then sign in with your Apple ID. AltStore's guide covers any extra prompts, such as a Mail plug-in on some macOS versions.
4. On the iPhone: **Settings → General → VPN & Device Management** → trust your Apple ID.
5. On the iPhone: **Settings → Privacy & Security → Developer Mode → On**. The phone will restart.
6. For automatic renewal over Wi-Fi: connect the iPhone by cable, open **Finder**, select the iPhone, and tick **Show this iPhone when on Wi-Fi**.

## Step 6. Install the app

1. AirDrop `EgyptIndustry.ipa` from your Mac to your iPhone. It's saved to the Files app.
2. Open **AltStore** on the iPhone → **My Apps** tab → **+** (top left) → pick `EgyptIndustry.ipa`.
3. The app appears on your home screen.

**Keeping it alive:** a free Apple ID's apps expire after 7 days. AltStore renews them in the background whenever your iPhone and Mac are on the same Wi-Fi with AltServer running. The **My Apps** tab shows how many days are left, and you can tap **Refresh All** at any time.

---

## Using the app

- **Pull down** on the list to fetch the latest data from GitHub.
- **Category chips** at the top filter by PMI & output, Policy, Investment or Trade. Tap again to clear.
- **Search** matches titles, summaries, sectors and sources.
- **Tap an item** for the full summary, the key figure, and a button to open the original article.

## Changing the code later

Edit the `.swift` files in Xcode, test with ▶ Run, then repeat Step 4 and Step 6 (installing again updates the app). You don't need to rebuild the app when new data arrives; it downloads it by itself.

### Getting a new version of the code from GitHub

1. Download the latest code as a zip (the link Claude gives you) and unzip it.
2. In Xcode's left sidebar, select all the `.swift` files inside the yellow `EgyptIndustry` folder → right-click → **Delete → Move to Trash**. Keep `news.json` and `Assets`.
3. Drag all the `.swift` files from the unzipped folder onto the yellow `EgyptIndustry` folder, with **Copy items if needed** ticked.
4. Press ▶ Run to test, then rebuild and reinstall (Steps 4 and 6).
