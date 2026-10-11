Config = {}

Config.AdminGroups = { 'admin', 'god' }
Config.AdminCommand = 'encontrosadmin'
Config.EventCommand = 'encontro'
Config.EventAreaRadius = 50
Config.EventHeightTolerance = 15.0
Config.BlipSpriteIdMin = 1
Config.BlipSpriteIdMax = 1000

-- Exige que o jogador chegue ao encontro com um carro proprio para contar presenca/premiacao.
-- ownership usa a tabela padrao do QBCore. Ajuste os nomes se sua garagem usar outro esquema.
Config.AttendanceVehicle = {
    required = true,
    driverOnly = false,
    types = {
        automobile = true,
    },
    ownership = {
        required = true,
        table = 'player_vehicles',
        ownerColumn = 'citizenid',
        plateColumn = 'plate',
    },
}

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


-- Usado pelo modo "Sortear local automaticamente" do painel.
-- Cada local precisa de coords (centro do encontro) e npc (mecanico de retirada).
-- Em eventos recorrentes, o proximo dia tenta evitar a mesma key do encontro anterior.
-- Com apenas um local valido configurado, a repeticao e inevitavel.
Config.Locations = {    
    {
        key = 'mercadao',
        label = 'Mercadão',
        coords = vector3(2769.48, 3467.65, 55.56),
        npc = vector4(2765.82, 3472.31, 55.67, 242.0),
        radius = 80.0,
        heightTolerance = 15.0,
    },
    {
        key = 'paleto towers',
        label = 'Estacionamento Paleto Towers',
        coords = vector3(53.23, 6333.66, 31.38),
        npc = vector4(76.96, 6341.51, 31.53, 88.71),
        radius = 80.0,
        heightTolerance = 15.0,
    },
    {
        key = 'pista xiquexique',
        label = 'Pista Automotiva Xique-xique',
        coords = vector3(1460.12, 6592.95, 14.43),
        npc = vector4(1504.57, 6587.40, 14.43, 79.98),
        radius = 80.0,
        heightTolerance = 15.0,
    },
    {
        key = 'cassino sandy shores',
        label = 'Cassino Sandy Shores',
        coords = vector3(1550.85, 3700.12, 34.47),
        npc = vector4(1533.98, 3694.71, 34.64, 312.61),
        radius = 60.0,
        heightTolerance = 15.0,
    },
    {
        key = 'concessionaria',
        label = 'Concessionária',
        coords = vector3(2363.66, 3133.08, 48.31),
        npc = vector4(2356.56, 3101.54, 48.20, 5.05),
        radius = 60.0,
        heightTolerance = 15.0,
    },

    -- Exemplo para adicionar mais locais:
    -- {
    --     key = 'pier',
    --     label = 'Pier',
    --     coords = vector3(-1570.78, -1018.64, 13.02),
    --     npc = vector4(-1565.25, -1012.40, 13.02, 140.0),
    --     radius = 70.0,
    --     heightTolerance = 15.0,
    -- },
    -- {
    --     key = 'casino',
    --     label = 'Estacionamento do Casino',
    --     coords = vector3(930.16, 41.71, 81.09),
    --     npc = vector4(924.42, 47.85, 81.10, 238.0),
    --     radius = 90.0,
    --     heightTolerance = 18.0,
    -- },
}
