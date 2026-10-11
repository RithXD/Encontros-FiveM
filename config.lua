Config = {}

Config.AdminGroups = { 'admin', 'god' }
Config.AdminCommand = 'encontrosadmin'
Config.EventCommand = 'encontro'
Config.EventAreaRadius = 50
Config.EventHeightTolerance = 15.0
Config.BlipSpriteIdMin = 1
Config.BlipSpriteIdMax = 1000

-- Interface independente do comando /encontro.
-- Para usar outras imagens, coloque os arquivos na pasta nui e adicione no fxmanifest.lua.
Config.PublicUi = {
    title = 'Encontros do Sertão',
    subtitle = 'Confira os encontros ativos agora',
    emptyTitle = 'Nenhum encontro ativo',
    emptyText = 'Quando um encontro estiver acontecendo, ele aparecerá aqui.',
    logo = '',
    mascot = '',
    footer = '',
    showBrand = false,
    showMascot = false,
    theme = {
        background = '#030405',
        surface = '#090a0c',
        card = '#101114',
        primary = '#1e3a8a',
        secondary = '#172554',
        text = '#f5f5f5',
        muted = '#a3a3a3',
        border = 'rgba(255, 255, 255, 0.13)',
    },
}

Config.RewardClaimNpc = {
    model = 's_m_m_autoshop_02',
    coords = vector4(1829.39, 3844.86, 36.75, 122.80),
    routingBucket = 0,
    label = 'Retirar peças dos encontros',
    blip = { sprite = 446, color = 3, scale = 0.7, label = 'Retirada de peças dos encontros' },
}

-- O mecânico local permanece por 10 minutos após o término real do encontro.
-- Depois disso, a retirada passa ao NPC fixo sem renovar o prazo do prêmio.
Config.EventRewardNpc = {
    model = 's_m_m_autoshop_02',
    distance = 2.0,
    afterFinishSeconds = 600,
}

-- Catalogo fixo: 26 pecas por categoria, uma unidade e chances iguais.
Config.RewardTables = EncounterRewardPolicy.tables()

Config.Blips = {
    encontro = { sprite = 280, color = 3, scale = 0.9, label = 'Encontro', radius = Config.EventAreaRadius, requiresNpc = true },
    marcador = { sprite = 280, color = 5, scale = 0.9, label = 'Marcador', radius = 0.0, requiresNpc = false },
}

Config.EventBlipIcons = {
    { sprite = 38, label = 'Bandeira de corrida' },
    { sprite = 73, label = 'Loja / roupa' },
    { sprite = 84, label = 'Lampião' },
    { sprite = 90, label = 'Aviao' },
    { sprite = 93, label = 'Bar / festa' },
    { sprite = 126, label = 'Triatlo' },
    { sprite = 136, label = 'Cinema / palco' },
    { sprite = 225, label = 'Carro' },
    { sprite = 226, label = 'Moto' },
    { sprite = 280, label = 'Grupo / encontro' },
    { sprite = 304, label = 'Estrela' },
    { sprite = 357, label = 'Garagem' },
    { sprite = 427, label = 'Barco' },
    { sprite = 442, label = 'lobo/caça' },
    { sprite = 446, label = 'Mecanica' },
    { sprite = 833, label = 'Caveira flamejante' }
}


-- OBS: a criacao pelo painel nao depende mais desta lista.
Config.Locations = {    
    {
        key = 'mercadao',
        label = 'Mercadão',
        coords = vector3(2769.48, 3467.65, 55.56),
        radius = 80.0,
        heightTolerance = 15.0,
    },
}
