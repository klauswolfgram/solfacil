#include 'totvs.ch'
#include 'rptdef.ch'
#include 'fwprintsetup.ch'

/*/{Protheus.doc} FIB1515
    Gera o registro da etiqueta na fila de impressao.
    @type User Function
    @author Klaus Wolfgram
    @since 25/10/2021
    @version 1.0

    @history 03/11/2022, Klaus Wolfgram, incluida chamada de impressao direta, para nao depender mais do job de impressao a partir do schedule.
                                        Ainda precisará ser ajustado quando a impressora da extrusao for substituida pelo novo modelo.
    @history 22/11/2022, Klaus Wolfgram, Retorna a descricao do recurso de acordo com o apontamento. Caso nao encontre um apontamento associado a etiqueta, retorna espaco vazio.
                                         
    /*/
    
User Function FIB1515()

Return fnGrvZ54()

/*/{Protheus.doc} fnGrvZ54
    Grava os dados da etiqueta na fila de impressao.
    @type  Static Function
    @author Klaus Wolfgram
    @since 26/10/2021
    @return lZ54, Boolean, Indica se o registro foi encontrado.
    @version 1.0
    /*/
Static Function fnGrvZ54

    Local cIdEtiq       := ''
    Local cOrdemPrd     := ''
    Local cProduto      := ''
    Local cLocEst       := ''
    Local nQtdPrd       := 0
    Local nPesoPrd      := 0
    Local cDataFin      := ''
    Local cHoraFin      := ''
    Local cDocto        := ''

    IF .not. Z51->Z51_TIPOAP $ '1|4'
        return
    EndIF

    IF .not. SC2->(dbSetOrder(1),dbSeek(Z51->(Z51_FILIAL+Z51_OP)))
        return .F.
    EndIF    

    IF .not. empty(Z51->Z51_IDETIQ)
        IF Z54->(dbSetOrder(1),dbSeek(xFilial(alias(),Z51->Z51_FILIAL) + Z51->Z51_IDETIQ))
            Return .T.
        EndIF        
    EndIF    

    cOrdemPrd   := Z51->Z51_OP
    cDocto      := Z51->Z51_NUMERO
    cProduto    := SC2->C2_PRODUTO
    cLocEst     := SC2->C2_LOCAL
    nQtdPrd     := Z51->Z51_QTD
    nPesoPrd    := Z51->Z51_QTD
    cDataFin    := dtos(Z51->Z51_DTFIN)
    cHoraFin    := Z51->Z51_HRFIN 
    cIdEtiq     := fnGetNum() //getSxeNum('Z54','Z54_IDETIQ'); confirmSX8()
    cRecurso    := Z51->Z51_RECUR

    Z54->(dbSetOrder(1),reclock(alias(),.T.))
        Z54->Z54_FILIAL := xFilial('Z54')
        Z54->Z54_IDETIQ := cIdEtiq
        Z54->Z54_OP     := cOrdemPrd
        Z54->Z54_DOC    := cDocto
        Z54->Z54_CODPRD := cProduto
        Z54->Z54_LOCEST := cLocEst
        Z54->Z54_QTDATU := nQtdPrd
        Z54->Z54_QTDIMP := 0
        Z54->Z54_PESO   := nPesoPrd
        Z54->Z54_DTFABR := stod(cDataFin)
        Z54->Z54_HRFABR := cHoraFin
        Z54->Z54_STATUS := ''
        Z54->Z54_RECUR  := cRecurso
        Z54->Z54_IMPRES := 'N'
    Z54->(msUnlock())  

    Z51->(reclock(alias(),.F.), Z51_IDETIQ := cIdEtiq     , msUnlock())   

    //-- Posiciona no roteiro de operacoes do produto pra verificar se eh uma etiqueta de extrusao
    SG2->(dbSetOrder(1),dbSeek(xFilial(alias(),Z54->Z54_FILIAL)+Z54->Z54_CODPRD))

    //-- Imprime etiquetas no modo antigo enquanto nao resolver a questão da impressora da extrusao do ES
    //-- Quando o novo modelo estiver disponivel tambem para este setor, essa chamada precisará ser ajustada
    IF Z54->Z54_FILIAL == '01' .and. "EXTRU" $ SG2->G2_DESCRI
        IF isInCallStack('U_FIB1511') //-- Se a chamada for a partir do recebimento da etiqueta via API
            fnImpZ51()
        EndIF    
    Else    
        //Imprime Etiqueta 
        U_FIB1534()
    EndIF   
    
Return .T.

/*/{Protheus.doc} Static Function getQrCode
    Programa auxiliar para exibir o qrcode gerado
    @type Static Function
    @since 25/10/2021
    /*/
Static Function getQrCode

    Local oDlg      := nil 
    Local oQrc

    Local cCod      := "TESTE QRCODE"
    Local cQrc      := ''
    Local aCords    := fwGetDialogSize(oMainWnd)
    Local aRemote   := getRmtInfo()
    Local cTemp     := iif('linux' $ lower(aRemote[02]),'l:/temp/','C:\Temp\')
    Local cFile     := ''

    oDlg            := tDialog():new(aCords[1],aCords[2],aCords[3],aCords[4],"QRCode",,,,,CLR_BLACK,CLR_WHITE,,,.T.)

    cCod            := CRLF + "CODIGO: 30500012005405"    
    oQrc            := fwQrCode():new({25,25,300,300},oDlg,cCod)
    cQrc            := oQrc:getCodeBar()
    cFile           := lower(oQrc:cDirName) + alltrim(lower(oQrc:cPngFile)) + '.png'
    cTemp           += alltrim(lower(oQrc:cPngFile)) + '.png'
    
    IF cFile <> cTemp
        __copyFile(cFile,cTemp)
    EndIF    

    oDlg:lCentered  := .T.
    
    oDlg:activate()

Return 

/*/{Protheus.doc} fnGetNum
    Retorna o proximo numero disponivel
    @type  Static Function
    /*/
Static Function fnGetNum()

    Local cAliasSQL := ''
    Local cSQL := ''
    Local cNumero := ''

    cSQL          := "SELECT isNull(MAX(Z54_IDETIQ),'') Z54_IDETIQ"
    cSQL          += CRLF + "FROM " + retSQLName("Z54") + " Z54"
    cSQL          += CRLF + "WHERE Z54.D_E_L_E_T_ = ' ' "
    cSQL          += CRLF + "AND Z54_FILIAL = '" + xFilial("Z54",cFilAnt) + "' " 

    cAliasSQL     := getNextAlias()

    dbUseArea(.T.,"TOPCONN",tcGenQry(,,cSQL),cAliasSQL,.T.,.F.)

    (cAliasSQL)->(dbEval({|| cNumero := Z54_IDETIQ}),dbCloseArea())

    IF empty(cNumero)
        cNumero := strzero(1,tamSX3('Z54_IDETIQ')[1])
    Else
        cNumero := soma1(cNumero)
    EndIF        
    
Return cNumero

/*/{Protheus.doc} fnPrnZPL
    Funcao auxiliar para impressao via ZPL
    @type  Static Function
    @author Klaus Wolfgram
    @since 26/04/2022
    @version 1.0
    /*/
Static Function fnPrnZPL()

    Local nRecZ53   := 0
    Local nRecZ51   := 0
    Local cEtiqueta := ''
    Local cAliasSQL := ''
    Local cSQL      := ''
    Local cImpress  := ''
    Local cCodigo   := ''
    
    Z55->(dbSetOrder(1),dbSeek(Z54->(Z54_FILIAL+Z54_OP)))
    SC2->(dbSetOrder(1),dbSeek(Z54->(Z54_FILIAL+Z54_OP)))
    SB1->(dbSetOrder(1),dbSeek(xFilial(alias(),SC2->C2_FILIAL)+SC2->C2_PRODUTO))

    IF alltrim(SB1->B1_UM) == 'MI'

        cSQL        := "SELECT R_E_C_N_O_ RECZ53"
        cSQL        += CRLF + "FROM " + retSQLName("Z53") + " Z53"
        cSQL        += CRLF + "WHERE Z53.D_E_L_E_T_ = ' ' "
        cSQL        += CRLF + "AND Z53_FILIAL = '" + Z54->Z54_FILIAL + "' "
        cSQL        += CRLF + "AND Z53_IDETIQ = '" + Z54->Z54_IDETIQ + "' "

        cAliasSQL   := getNextAlias()

        dbUseArea(.T.,"TOPCONN",tcGenQry(,,cSQL),cAliasSQL,.T.,.F.)

        (cAliasSQL)->(dbEval({|| nRecZ53 := RECZ53}),dbCloseArea())

        IF empty(nRecZ53)
            return
        EndIF

        Z53->(dbSetOrder(1),dbGoTo(nRecZ53))
        Z57->(dbSetOrder(1),dbSeek(Z53->(Z53_FILIAL+Z53_CODIGO)))
        Z51->(dbSetOrder(1),dbSeek(Z57->(Z57_FILIAL+Z57_CODZ51)))

        IF empty(Z54->Z54_DOC)
            Z54->(reclock(alias(),.F.),Z54_DOC := iif(empty(Z51->Z51_NUMERO),substr(Z51->Z51_OP,1,6),Z51->Z51_NUMERO),msunlock())
        EndIF  

        Z56->(dbSetOrder(1),dbSeek(Z51->(Z51_FILIAL+Z51_RECUR)))

        While .not. Z56->(eof()) .and. Z56->(Z56_FILIAL+Z56_RECURS) == Z51->(Z51_FILIAL+Z51_RECUR)

            cImpress := alltrim(Z56->Z56_IMPRES)

            IF empty(cImpress)
                Z56->(dbSkip())
                Loop
            EndIF

            exit        

        Enddo 

        IF empty(cImpress)
            return
        EndIF  

        IF substr(cImpress,1,2) <> '\\'
            return
        EndIF     

//      waitRun("NET USE " + "LPT1"                      + " /DELETE"        , 0)
//      waitRun("NET USE " + "LPT1 " + alltrim(cImpress) + " /PERSISTENT:YES", 0)          

        cCodigo   := alltrim(Z54->Z54_IDETIQ ) + '|'
        cCodigo   += alltrim(Z54->Z54_CODPRD ) + '|'
        cCodigo   += alltrim(SB1->B1_DESC    ) + '|'    
        cCodigo   += alltrim(Z54->Z54_OP     ) + '|'
        cCodigo   += alltrim(Z54->Z54_DOC    ) + '|'
        cCodigo   += dtoc(Z54->Z54_DTFABR    ) + '|'
        cCodigo   += alltrim(Z54->Z54_HRFABR ) + '|'
        cCodigo   += cValToChar(Z54->Z54_PESO)   

        cRecurso  := fnGetRec()                

        cEtiqueta := ""
        cEtiqueta += CRLF + "^XA
        cEtiqueta += CRLF + "^FO025,025"
        cEtiqueta += CRLF + "^BQN,2,06"
        cEtiqueta += CRLF + "^FDQA," + cCodigo + "^FS"
        cEtiqueta += CRLF + "^FT240,060^A0N,32,32^FH\^FDFIBRASA S/A^FS"
        cEtiqueta += CRLF + "^FT240,090^A0N,32,32^FH\^FDOP: "       + Z54->Z54_OP                + "^FS"
        cEtiqueta += CRLF + "^FT240,120^A0N,32,32^FH\^FDDOC: "      + Z54->Z54_DOC               + "^FS"
        cEtiqueta += CRLF + "^FT240,150^A0N,32,32^FH\^FDRECURSO: "  + cRecurso                   + "^FS"
        cEtiqueta += CRLF + "^FT240,180^A0N,32,32^FH\^FDPRODUTO: "  + alltrim(Z54->Z54_CODPRD   )+ "^FS"
        cEtiqueta += CRLF + "^FT240,210^A0N,32,32^FH\^FDPESO: "     + cValToChar(Z54->Z54_QTDATU)+ "^FS"
        cEtiqueta += CRLF + "^FT025,270^A0N,32,32^FH\^FDDATA: "     + dtoc(Z54->Z54_DTFABR      )+ "^FS"
        cEtiqueta += CRLF + "^FT280,270^A0N,32,32^FH\^FDHORA: "     + alltrim(Z54->Z54_HRFABR   )+ "^FS"
        cEtiqueta += CRLF + "^FT025,300^A0N,32,32^FH\^FD"           + alltrim(SB1->B1_DESC      )+ "^FS"
        cEtiqueta += CRLF + "^FT025,330^A0N,32,32^FH\^FDID.:"       + alltrim(Z54->Z54_IDETIQ   )+ "^FS"
        cEtiqueta += CRLF + "^XZ"   

        mscbPrinter("ZEBRA","LPT1",,40,.F.)
        mscbChkStatus(.F.)
        mscbBegin(1,6)
        mscbWrite(cEtiqueta)
        mscbEnd()
        mscbClosePrinter() 

        Z54->(reclock(alias(),.F.),Z54_IMPRES := "S",msunlock())

        return

    EndIF

    cSQL      := "SELECT R_E_C_N_O_ RECZ51"
    cSQL      += CRLF + "FROM " + retSQLName("Z51") + " Z51"
    cSQL      += CRLF + "WHERE Z51.D_E_L_E_T_ = ' ' "
    cSQL      += CRLF + "AND Z51_FILIAL = '" + Z54->Z54_FILIAL + "' "
    cSQL      += CRLF + "AND Z51_OP = '"     + Z54->Z54_OP     + "' "
    cSQL      += CRLF + "AND Z51_IDETIQ = '" + Z54->Z54_IDETIQ + "' "
    cSQL      += CRLF + "ORDER BY Z51_FILIAL,Z51_CODIGO"

    cAliasSQL := getNextAlias()

    dbUseArea(.T.,"TOPCONN",tcGenQry(,,cSQL),cAliasSQL,.T.,.F.)

    (cAliasSQL)->(dbEval({|| nRecZ51 := RECZ51}),dbCloseArea())

    IF nRecZ51 = 0
        return
    EndIF

    Z51->(dbSetOrder(1),dbGoTo(nRecZ51))

    IF empty(Z54->Z54_DOC)
        Z54->(reclock(alias(),.F.),Z54_DOC := iif(empty(Z51->Z51_NUMERO),substr(Z51->Z51_OP,1,6),Z51->Z51_NUMERO),msunlock())
    EndIF

    Z56->(dbSetOrder(1),dbSeek(Z51->(Z51_FILIAL+Z51_RECUR)))

    While .not. Z56->(eof()) .and. Z56->(Z56_FILIAL+Z56_RECURS) == Z51->(Z51_FILIAL+Z51_RECUR)

        cImpress := alltrim(Z56->Z56_IMPRES)

        IF empty(cImpress)
            Z56->(dbSkip())
            Loop
        EndIF

        exit        

    Enddo         

    cCodigo   := alltrim(Z54->Z54_IDETIQ ) + '|'
    cCodigo   += alltrim(Z54->Z54_CODPRD ) + '|'
    cCodigo   += alltrim(SB1->B1_DESC    ) + '|'    
    cCodigo   += alltrim(Z54->Z54_OP     ) + '|'
    cCodigo   += alltrim(Z54->Z54_DOC    ) + '|'
    cCodigo   += dtoc(Z54->Z54_DTFABR    ) + '|'
    cCodigo   += alltrim(Z54->Z54_HRFABR ) + '|'
    cCodigo   += cValToChar(Z54->Z54_PESO)     

    cRecurso  := fnGetRec()

    cEtiqueta := ""
    cEtiqueta += CRLF + "^XA
    cEtiqueta += CRLF + "^FO025,025"
    cEtiqueta += CRLF + "^BQN,2,06"
    cEtiqueta += CRLF + "^FDQA," + cCodigo + "^FS"
    cEtiqueta += CRLF + "^FT240,060^A0N,32,32^FH\^FDFIBRASA S/A^FS"
    cEtiqueta += CRLF + "^FT240,090^A0N,32,32^FH\^FDOP: "       + Z54->Z54_OP                + "^FS"
    cEtiqueta += CRLF + "^FT240,120^A0N,32,32^FH\^FDDOC: "      + Z54->Z54_DOC               + "^FS"
    cEtiqueta += CRLF + "^FT240,150^A0N,32,32^FH\^FDRECURSO: "  + cRecurso                   + "^FS"
    cEtiqueta += CRLF + "^FT240,180^A0N,32,32^FH\^FDPRODUTO: "  + alltrim(Z54->Z54_CODPRD   )+ "^FS"
    cEtiqueta += CRLF + "^FT240,210^A0N,32,32^FH\^FDPESO: "     + cValToChar(Z54->Z54_QTDATU)+ "^FS"
    cEtiqueta += CRLF + "^FT025,270^A0N,32,32^FH\^FDDATA: "     + dtoc(Z54->Z54_DTFABR      )+ "^FS"
    cEtiqueta += CRLF + "^FT280,270^A0N,32,32^FH\^FDHORA: "     + alltrim(Z54->Z54_HRFABR   )+ "^FS"
    cEtiqueta += CRLF + "^FT025,300^A0N,32,32^FH\^FD"           + alltrim(SB1->B1_DESC      )+ "^FS"
    cEtiqueta += CRLF + "^FT025,330^A0N,32,32^FH\^FDID.:"       + alltrim(Z54->Z54_IDETIQ   )+ "^FS"
    cEtiqueta += CRLF + "^XZ"   

    cImpress := "\\192.168.200.78\zt230"
//  waitRun("NET USE LPT1 /DELETE")
//  waitRun("NET USE " + "LPT1 " + alltrim(cImpress) + " /PERSISTENT:YES", 0)
        
    mscbPrinter("ZEBRA","LPT1",,40,.F.)
    mscbChkStatus(.F.)
    mscbBegin(1,6)
    mscbWrite(cEtiqueta)
    mscbEnd()
    mscbClosePrinter()    

    Z54->(reclock(alias(),.F.),Z54_IMPRES := "S",msunlock())      
    
Return

/*/{Protheus.doc} fnGetRec
    Retorna a descricao do nome do recurso a ser impresso na etiqueta.
    @type  Static Function
    @author Klaus Wolfgram
    @since 17/11/2022
    /*/
Static Function fnGetRec()

    Local cRecurso := ''
    Local cAliasSQL := getNextAlias()

    BeginSQL alias cAliasSQL 
        SELECT Z51_RECUR, H1_DESCRI
        FROM %table:Z51% Z51
        JOIN %table:SH1% SH1 ON SH1.%notdel% AND H1_FILIAL = %exp:xFilial('SH1',Z54->Z54_FILIAL)% AND H1_CODIGO = Z51_RECUR
        WHERE Z51.%notdel%
        AND Z51_FILIAL = %exp:Z54->Z54_FILIAL%
        AND Z51_IDETIQ = %exp:Z54->Z54_IDETIQ%
        ORDER BY Z51_CODIGO
    EndSQL

    (cAliasSQL)->(dbEval({|| cRecurso := H1_DESCRI}),dbCloseArea())
    
Return alltrim(cRecurso)

/*/{Protheus.doc} fnImpZ51
    Imprime a etiqueta de bobina
    @type  Static Function
    @author Klaus Wolfgram
    @since 14/03/2022
    @version 1.0
    /*/
Static Function fnImpZ51()

    Local cImpress  := iif(isBlind(),'Doro PDF Writer','Microsoft Print to PDF')//'ZDesigner ZT230-300dpi ZPL'
    Local cCod      := ''
    Local cDataFabr := '' 
    Local oFontN    := tFont():new('Arial',,-12) //tFont():new('Arial',,-16)
    Local oFontB    := tFont():new('Arial',,-14) //tFont():new('Arial',,-16)
    Local oFontC    := tFont():new('Arial',,-12) //tFont():new('Arial',,-16)
    Local oPrint    := Nil

    oFontC:bold     := .T.
    oFontN:bold     := .F.
    oFontB:bold     := .F.

    IF .not. existDir('\_LOG')
        makeDir('\_LOG')
    EndIF

    IF .not. existDir('\_LOG\FIB1530')
        makeDir('\_LOG\FIB1530')
    EndIF     

    cImpress           := fnGetImpr()
    cImpress           := cImpress

    oPrint             := fwMsPrinter():new('FIB1530_' + Z54->Z54_IDETIQ + '.rel',IMP_SPOOL,.T.,,.T.,.F.,,cImpress,.F.)
    oPrint:cPathPDF    := '\_LOG\FIB1530\'         
    oPrint:cPrinter    := cImpress        
    oPrint:setPortrait(.T.)
    oPrint:setDevice(IMP_SPOOL)
    oPrint:setPaperSize(2)
    oPrint:setMargin(10,10,10,10)    
    oPrint:setParm("-RFS")

    SB1->(dbSetOrder(1),dbSeek(xFilial(alias(),Z54->Z54_FILIAL)+Z54->Z54_CODPRD))

    cCod               += alltrim(Z54->Z54_IDETIQ ) + '|'
    cCod               += alltrim(Z54->Z54_CODPRD ) + '|'
    cCod               += alltrim(SB1->B1_DESC    ) + '|'    
    cCod               += alltrim(Z54->Z54_OP     ) + '|'
    cCod               += alltrim(Z54->Z54_DOC    ) + '|'
    cCod               += dtoc(Z54->Z54_DTFABR    ) + '|'
    cCod               += alltrim(Z54->Z54_HRFABR ) + '|'
    cCod               += cValToChar(Z54->Z54_PESO)

    cDataFabr          := dtoc(Z54->Z54_DTFABR) + space(10)
    cHora              := alltrim(Z54->Z54_HRFABR ) 

    cPeso              := cValToChar(Z54->Z54_QTDATU)   
//  cRecurso           := alltrim(Z54->Z54_RECUR)

//  IF .not. empty(cRecurso)
//      IF SH1->(dbSetOrder(1),dbSeek(xFilial("SH1",Z54->Z54_FILIAL)+Z54->Z54_RECUR))
//          cRecurso       := alltrim(SH1->H1_DESCRI)
//      EndIF   
//  EndIF 

    //-- @history 17/11/2022, Klaus Wolfgram, Selecao do nome do recurso a ser impresso na etiqueta.
    cRecurso            := fnGetRec()

    IF Z54->Z54_QTDATU = 0
        return
    EndIF

    oPrint:startpage()

    oPrint:qrCode(300,050,cCod,075)
    oPrint:say(050, 350, 'FIBRASA S/A'                           ,oFontB)
    oPrint:say(100, 350, 'DATA.: '       + cDataFabr             ,oFontN)
    oPrint:say(150, 350, 'HORA: '        + cHora                 ,oFontN)    
    oPrint:say(200, 350, 'OP.: '         + Z54->Z54_OP           ,oFontB)
    oPrint:say(250, 350, 'DOC.: '        + Z54->Z54_DOC          ,oFontN)
    oPrint:say(300, 350,                   cRecurso              ,oFontN)
    oPrint:say(350, 050, 'PROD.: '       + Z54->Z54_CODPRD       ,oFontN)               
    oPrint:say(400, 050, alltrim(SB1->B1_DESC)                   ,oFontB) 
    oPrint:say(450, 050, 'ID.:'          + Z54->Z54_IDETIQ       ,oFontN)
    oPrint:say(500, 050, 'PESO.: '       + cPeso                 ,oFontB)            
  
    oPrint:endpage()
    oPrint:print()

    //-- Atualiza a variavel de controle para indicar que houve a impressao
    IF Z54->(reclock(alias(),.F.))
            Z54->Z54_IMPRES := 'S'
            Z54->Z54_QTDIMP := Z54->Z54_QTDIMP + 1
            Z54->Z54_OBS    := 'ETIQUETA ENVIADA PARA IMPRESSORA ' + cImpress
        Z54->(msunlock())
    EndIF

Return .T.

/*/{Protheus.doc} fnGetImpr
    Retorna a impressora termica para impressao da etiqueta de acordo com o recurso posicionado.
    @type  Static Function
    @author Klaus Wolfgram
    @since 03/08/2022
    @version 1.0
    /*/
Static Function fnGetImpr()

    Local cImpress      := ''
    Local cAliasSQL     := ''
    Local aImpInst      := getImpWindows(.F.) 
    Local lret          := .F.
    Local cRecurso      := Z54->Z54_RECUR
    Local x

    //-- Se o recurso nao tiver sido informado na etiqueta, é necessario buscar o recurso da OP em que a etiqueta tiver sido usada pela ultima vez
    IF empty(cRecurso)

        cAliasSQL       := getNextAlias()

        BeginSQL alias cAliasSQL
            SELECT Z55_RECURS 
            FROM %table:Z52% Z52
            JOIN %table:Z55% Z55 ON Z55.%notdel% AND Z55_FILIAL = Z52_FILIAL AND Z55_OP = Z52_OP
            WHERE Z52.%notdel%
            AND Z52_FILIAL = %exp:xFilial('Z52',Z54->Z54_FILIAL)%
            AND Z52_IDETQ  = %exp:Z54->Z54_IDETIQ%
            ORDER BY Z52_CODIGO
        EndSQL

        (cAliasSQL)->(dbEval({|| cRecurso := Z55_RECURS}),dbCloseArea())

    EndIF

    cAliasSQL           := getNextAlias()

    BeginSQL Alias cAliasSQL
        SELECT * FROM %table:Z56% Z56
        WHERE Z56.%notdel%
        AND Z56_FILIAL = %exp:Z54->Z54_FILIAL%
        AND Z56_RECURS = %exp:cRecurso%
    EndSQL

    While .not. (cAliasSQL)->(eof())

        cImpress := alltrim((cAliasSQL)->Z56_IMPRES)

        For x := 1 To Len(aImpInst)
            IF alltrim(aImpInst[x]) == cImpress
                lret := .T.
                exit
            EndIF    
        Next

        IF lret
            exit
        EndIF

        cImpress := ''    

        (cAliasSQL)->(dbSkip())

    Enddo

    (cAliasSQL)->(dbCloseArea())
    
Return cImpress
