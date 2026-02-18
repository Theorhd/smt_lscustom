fx_version 'adamant'

game 'gta5'

lua54 'yes'

name 'smtrp_lscustom'
version '1.0.0'
description 'SMTRP LS Customs with RageUI'

shared_scripts {
    '@es_extended/imports.lua',
    '@es_extended/locale.lua',
    'locales/*.lua',
    'config.lua'
}

client_scripts {
    '@RageUI/RMenu.lua',
    '@RageUI/components/Visual.lua',
    '@RageUI/components/Text.lua',
    '@RageUI/components/Sprite.lua',
    '@RageUI/components/Rectangle.lua',
    '@RageUI/components/Keys.lua',
    '@RageUI/components/Enum.lua',
    '@RageUI/components/Audio.lua',
    '@RageUI/menu/elements/PanelColour.lua',
    '@RageUI/menu/elements/ItemsColour.lua',
    '@RageUI/menu/elements/ItemsBadge.lua',
    '@RageUI/menu/items/UIButton.lua',
    '@RageUI/menu/items/UIList.lua',
    '@RageUI/menu/items/UISlider.lua',
    '@RageUI/menu/items/UISliderProgress.lua',
    '@RageUI/menu/items/UISliderHeritage.lua',
    '@RageUI/menu/items/UISeparator.lua',
    '@RageUI/menu/items/UICheckBox.lua',
    '@RageUI/menu/panels/UIStatisticsPanel.lua',
    '@RageUI/menu/panels/UIPercentagePanel.lua',
    '@RageUI/menu/panels/UIGridPanel.lua',
    '@RageUI/menu/panels/UIColourPanel.lua',
    '@RageUI/menu/windows/UIHeritage.lua',
    '@RageUI/menu/RageUI.lua',
    '@RageUI/menu/Menu.lua',
    '@RageUI/menu/MenuController.lua',
    '@ox_lib/init.lua',
    'client/main.lua'
}

files {
    'stream/header.png',
    'stream/header-bg.png'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    '@ox_lib/init.lua',
    'server/main.lua'
}

dependencies {
    'es_extended',
    'RageUI',
    'ox_lib'
}
