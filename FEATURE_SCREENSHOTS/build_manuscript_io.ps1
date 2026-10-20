$ErrorActionPreference = 'Stop'
$outDir = 'e:\dreamweaver\FEATURE_SCREENSHOTS\MANUSCRIPT_IO'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$map = [ordered]@{
  '01_Login.png' = 'e:\dreamweaver\tools\shots\01_login.png'
  '02_Register.png' = 'e:\dreamweaver\tools\shots\01b_register.png'
  '03_MainMenu.png' = 'e:\dreamweaver\tools\shots\02_main_menu.png'
  '04_StoryIntro.png' = 'e:\dreamweaver\tools\shots\03_story_intro.png'
  '05_Tutorial.png' = 'e:\dreamweaver\tools\shots\04_tutorial.png'
  '06_HubBleached.png' = 'e:\dreamweaver\tools\shots\05_hub.png'
  '07_Chapter1.png' = 'e:\dreamweaver\tools\shots\06_chapter1.png'
  '08_Dialogue.png' = 'e:\dreamweaver\FEATURE_SCREENSHOTS\03_Dialogue_System.png'
  '09_CombatBoss.png' = 'e:\dreamweaver\FEATURE_SCREENSHOTS\04_Combat_Boss_Slam.png'
  '10_CombatMinions.png' = 'e:\dreamweaver\FEATURE_SCREENSHOTS\05_Combat_Shadow_Minions.png'
  '11_HubRestored.png' = 'e:\dreamweaver\tools\shots\hub_restored.png'
  '12_Ending.png' = 'e:\dreamweaver\tools\shots\07_ending.png'
}

foreach ($k in $map.Keys) {
  Copy-Item -LiteralPath $map[$k] -Destination (Join-Path $outDir $k) -Force
}

$entries = @(
  [pscustomobject]@{
    n = 1; title = 'Game Login'
    input = 'The player opens the installed Dreamweaver application. Action: Enters a registered email or username and password, then selects Login.'
    output = 'The Login screen displays the Dreamweaver title art with fields for account credentials and options to sign in or create a new account.'
    img = '01_Login.png'; cap = 'Sample login screen output'
  },
  [pscustomobject]@{
    n = 2; title = 'Create Account'
    input = 'A new player opens the Register screen. Action: Enters account details and confirms registration.'
    output = 'The registration form is submitted. Successful registration allows the player to sign in and continue to the Gateway (Main Menu). Validation messages guide the player if required fields are incomplete.'
    img = '02_Register.png'; cap = 'Sample input screen for account registration'
  },
  [pscustomobject]@{
    n = 3; title = 'Main Menu (The Gateway)'
    input = 'The player completes sign-in with a valid account. Action: Lands on the Gateway after authentication.'
    output = 'The Main Menu displays New Game, Load Game, Lore Codex, Settings, and Exit. From here the player begins a new playthrough or continues a saved run.'
    img = '03_MainMenu.png'; cap = 'Sample Main Menu output after sign-in'
  },
  [pscustomobject]@{
    n = 4; title = 'Story Prologue'
    input = 'The player selects New Game from the Gateway. Action: Advances through the prologue panels.'
    output = 'The Story Intro presents the prologue narrative ("The Road Beyond") with a progress track and a Skip option. Selecting Begin the journey continues into the tutorial.'
    img = '04_StoryIntro.png'; cap = 'Sample story prologue output'
  },
  [pscustomobject]@{
    n = 5; title = "Tutorial - Slang Awakening"
    input = 'The player finishes the prologue and enters the tutorial scene. Action: Moves the player character and advances narrator dialogue with E.'
    output = 'The tutorial room appears in a bleached grayscale state. The HUD shows lives and health, the objective reads "Wake in the bleached room," and the dialogue box types narrator text with an E continue prompt.'
    img = '05_Tutorial.png'; cap = 'Sample tutorial dialogue and objective output'
  },
  [pscustomobject]@{
    n = 6; title = 'Hub World - Crossroads of the Five Houses'
    input = 'The player completes the tutorial and receives the Lewet Staff. Action: Walks the boardwalk toward a House door and presses E to enter.'
    output = 'The hub shows five labeled Houses (Black Foundation, Red Courage, Golden Sun, Dream Ancestors, Sacred Loom). The objective panel, health bars, essence slots, and interaction prompt are visible while the world remains desaturated.'
    img = '06_HubBleached.png'; cap = 'Sample hub world output (color not yet restored)'
  },
  [pscustomobject]@{
    n = 7; title = 'Chapter 1 - House of the Black Foundation'
    input = 'The player enters Black Foundation from the hub. Action: Explores the cold hall to find the Spirit of the Fiber.'
    output = 'The chapter interior loads with the House objective, HUD, and Lewet Staff essence indicators. Interactive props such as the loom, baskets, and spirit appear in the isometric room.'
    img = '07_Chapter1.png'; cap = 'Sample Chapter 1 house interior output'
  },
  [pscustomobject]@{
    n = 8; title = 'Dialogue System'
    input = 'The player approaches an NPC or story trigger inside a chapter or tutorial. Action: Presses E to continue each line.'
    output = 'The woven dialogue panel appears with a speaker label, typewriter text, and an E continue hint. Portrait wells light for active speakers when character dialogue is used.'
    img = '08_Dialogue.png'; cap = 'Sample dialogue system output'
  },
  [pscustomobject]@{
    n = 9; title = 'Combat - Shadow Weaver Boss Attack'
    input = 'The player reaches the Sacred Loom duel or boss encounter. Action: Dodges and answers the Shadow Weaver slam with staff strikes and chime using Space and Q.'
    output = 'The Shadow Weaver performs a slam ability with a purple radial burst and rising shadow VFX, indicating an area attack during the real-time boss fight.'
    img = '09_CombatBoss.png'; cap = 'Sample boss slam combat output'
  },
  [pscustomobject]@{
    n = 10; title = 'Combat - Shadow Minions'
    input = 'The player engages shadow enemies on the ridge or during Chapter 5 waves. Action: Attacks with the Lewet Staff and uses the sonic chime.'
    output = 'Shadow minions spawn and hunt the player using combat styles (chaser, stalker, dasher, caster). Defeated shadows award score and a small heal.'
    img = '10_CombatMinions.png'; cap = 'Sample shadow minion combat output'
  },
  [pscustomobject]@{
    n = 11; title = 'Color Restoration - World Restored'
    input = 'The player restores the Houses and defeats the Shadow Weaver. Action: Triggers the Color Burst at the end of Chapter 5.'
    output = 'The grayscale veil clears. The Crossroads returns to full colour, House labels show restored status, and the banner announces that the world is whole again.'
    img = '11_HubRestored.png'; cap = 'Sample color restoration output after Color Burst'
  },
  [pscustomobject]@{
    n = 12; title = 'Ending'
    input = 'The player completes the final Sacred Loom sequence. Action: Watches the closing sequence and ending screen.'
    output = 'The Ending scene displays the final rank, score summary, and credits or return options after the world is restored.'
    img = '12_Ending.png'; cap = 'Sample ending screen output'
  }
)

$word = New-Object -ComObject Word.Application
$word.Visible = $false
$doc = $word.Documents.Add()
$sel = $word.Selection

function Set-FontNormal {
  $sel.Font.Name = 'Times New Roman'
  $sel.Font.Size = 12
  $sel.Font.Bold = $false
  $sel.Font.Italic = $false
}

# Title
$sel.ParagraphFormat.Alignment = 1
$sel.Font.Name = 'Times New Roman'
$sel.Font.Size = 14
$sel.Font.Bold = $true
$sel.TypeText('APPENDIX')
$sel.TypeParagraph()
$sel.Font.Size = 12
$sel.TypeText('Sample Screenshots of Dreamweaver: The Legend of Fun Kdungon')
$sel.TypeParagraph()

$sel.ParagraphFormat.Alignment = 0
Set-FontNormal
$sel.TypeText('This appendix presents sample player inputs and their corresponding screen outputs for Dreamweaver: The Legend of Fun Kdungon. Each item shows the player action (Input), the resulting game screen (Output), and a captured screenshot from the build.')
$sel.TypeParagraph()

foreach ($e in $entries) {
  $sel.ParagraphFormat.Alignment = 0
  $sel.ParagraphFormat.SpaceBefore = 12
  $sel.ParagraphFormat.SpaceAfter = 6
  $sel.Font.Name = 'Times New Roman'
  $sel.Font.Size = 12
  $sel.Font.Bold = $true
  $sel.Font.Italic = $false
  $sel.TypeText("$($e.n). $($e.title)")
  $sel.TypeParagraph()

  $sel.ParagraphFormat.SpaceBefore = 0
  $sel.Font.Bold = $true
  $sel.TypeText('Input: ')
  $sel.Font.Bold = $false
  $sel.TypeText($e.input)
  $sel.TypeParagraph()

  $sel.Font.Bold = $true
  $sel.TypeText('Output: ')
  $sel.Font.Bold = $false
  $sel.TypeText($e.output)
  $sel.TypeParagraph()

  $imgPath = Join-Path $outDir $e.img
  $sel.ParagraphFormat.Alignment = 1
  $pic = $sel.InlineShapes.AddPicture($imgPath, $false, $true)
  $pic.LockAspectRatio = -1
  $pic.Width = 420
  $sel.TypeParagraph()

  $sel.Font.Name = 'Times New Roman'
  $sel.Font.Size = 11
  $sel.Font.Italic = $true
  $sel.Font.Bold = $false
  $sel.ParagraphFormat.Alignment = 1
  $sel.TypeText($e.cap)
  $sel.TypeParagraph()
  $sel.Font.Italic = $false
}

$savePath = Join-Path $outDir 'Dreamweaver_Appendix_Input_Output.docx'
# wdFormatXMLDocument = 12 (.docx)
$doc.SaveAs2($savePath, 12)
$doc.Close($false)
$word.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($sel) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($doc) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($word) | Out-Null
[GC]::Collect()

Write-Output "SAVED $savePath"
Get-Item $savePath | Format-List FullName, Length
explorer.exe $outDir
