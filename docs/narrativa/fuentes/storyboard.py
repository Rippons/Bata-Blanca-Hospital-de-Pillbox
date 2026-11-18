import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Circle, FancyArrow, FancyBboxPatch
from matplotlib.backends.backend_pdf import PdfPages
import textwrap

def fig_person(ax,x,y,label,color='#222',bata=False,s=1.0):
    ax.add_patch(Circle((x,y+1.6*s),0.35*s,fill=False,lw=2,ec=color))
    ax.plot([x,x],[y+1.25*s,y+0.4*s],color=color,lw=2)
    ax.plot([x-0.5*s,x,x+0.5*s],[y+0.7*s,y+1.0*s,y+0.7*s],color=color,lw=2)
    ax.plot([x-0.35*s,x,x+0.35*s],[y-0.2*s,y+0.4*s,y-0.2*s],color=color,lw=2)
    if bata: ax.add_patch(Rectangle((x-0.3*s,y+0.4*s),0.6*s,0.85*s,fc='white',ec=color,lw=1.2,zorder=0))
    ax.text(x,y-0.65*s,label,ha='center',fontsize=7.5,weight='bold')
def camilla(ax,x,y,n,paciente=None,bar=None,barcol='#555'):
    ax.add_patch(Rectangle((x,y),2.4,0.9,fc='#eee',ec='#333',lw=1.3))
    ax.text(x+1.2,y-0.35,f'camilla {n}',ha='center',fontsize=6.5,color='#444')
    if paciente:
        ax.add_patch(Circle((x+0.4,y+0.45),0.28,fill=False,ec='#222',lw=1.5)); ax.plot([x+0.7,x+2.1],[y+0.45,y+0.45],color='#222',lw=2)
        ax.text(x+1.2,y+1.45 if bar is not None else y+1.1,paciente,ha='center',fontsize=7)
    if bar is not None:
        ax.add_patch(Rectangle((x+0.2,y+1.0),2.0,0.22,fc='white',ec='#333',lw=.8))
        ax.add_patch(Rectangle((x+0.2,y+1.0),2.0*bar,0.22,fc=barcol,ec='none'))
def caja(ax,x,y,w,h,txt,fc='#f4f4f4',lw=1.3,fs=7):
    ax.add_patch(Rectangle((x,y),w,h,fc=fc,ec='#333',lw=lw)); ax.text(x+w/2,y+h/2,txt,ha='center',va='center',fontsize=fs)
def flecha(ax,x,y,dx,dy): ax.add_patch(FancyArrow(x,y,dx,dy,width=0.05,head_width=0.3,head_length=0.35,color='#000',length_includes_head=True))
def hud(ax,obj,rep,extra=''):
    ax.add_patch(Rectangle((0.15,8.75),11.7,1.1,fc='white',ec='#888',lw=.8))
    ax.add_patch(Rectangle((0.15,8.75),11.7,1.1,fc='white',ec='#888',lw=.8))
    ax.text(0.35,9.52,f'Objetivo: {obj}',fontsize=6.8,va='center')
    ax.text(0.35,9.05,f'Reputación {rep} · {extra}',fontsize=6.8,va='center',color='#444')
def bocadillo(ax,x,y,txt,w=4.6):
    lines=textwrap.wrap(txt,int(w*6.2)); h=0.38*len(lines)+0.3
    ax.add_patch(FancyBboxPatch((x,y),w,h,boxstyle='round,pad=0.1',fc='white',ec='#222',lw=1))
    ax.text(x+0.15,y+h-0.25,'\n'.join(lines),fontsize=6.6,va='top')

def V01(ax):
    hud(ax,'Atiende a Don Ramiro (camilla 1)','0','Interno')
    caja(ax,0.3,0.4,1.5,3,'PUERTA',fc='#fff'); ax.text(1.05,3.7,'IntroTrigger',ha='center',fontsize=6)
    caja(ax,9.0,4.6,2.8,2.6,'TABLÓN DE\nCAPACITA-\nCIONES\n[bloqueado]',fc='#ccc',fs=6.3)
    camilla(ax,5.5,1.0,1,'Don Ramiro',0.8)
    fig_person(ax,3.1,1.0,'Walter',bata=True); fig_person(ax,5.4,4.6,'Dr. Salgado',bata=True)
    flecha(ax,1.9,0.9,0.6,0)
    bocadillo(ax,0.4,5.6,'Salgado: «Bienvenido a Pillbox, Pinkman. Si haces bien tu guardia, el tablón se abre para ti».',w=3.6)
def V02(ax):
    hud(ax,'Atiende a Don Ramiro (camilla 1)','0','Interno')
    camilla(ax,0.6,3.0,1,'Don Ramiro',0.7)
    fig_person(ax,4.1,3.0,'Walter',bata=True)
    caja(ax,5.4,1.0,6.2,6.8,'',fc='#fafafa',lw=1.6)
    ax.text(8.5,7.3,'PANEL DE DIAGNÓSTICO',ha='center',fontsize=8,weight='bold')
    ax.text(5.7,6.5,'Signos: corte en la palma,\nsangrado leve, consciente',fontsize=7,va='top')
    for i,t in enumerate(['1  Herida superficial','2  Fractura','3  Quemadura']):
        caja(ax,6.0,4.2-i*1.05,5.0,0.8,t,fc='#ddd' if i==0 else '#fff')
    ax.text(3.2,0.3,'[E] examinar',fontsize=7,ha='center')
def V03(ax):
    hud(ax,'Busca el insumo → aplica','10','Interno')
    caja(ax,0.5,4.6,2.6,2.4,'BOTIQUÍN A\nvendaje ×2\nantipirético ×2',fs=6.5)
    camilla(ax,7.6,1.4,1,'Don Ramiro',1.0,barcol='#999')
    fig_person(ax,4.8,2.2,'Walter (carga vendaje)',bata=True)
    caja(ax,4.3,4.45,1.0,0.45,'vendaje',fc='#fff',fs=5.5)
    flecha(ax,3.3,5.4,1.2,-1.6); flecha(ax,5.6,2.6,1.8,0)
    ax.text(9.3,4.0,'¡Estable!\n+10 reputación',ha='center',fontsize=8,weight='bold')
def V04(ax):
    hud(ax,'Atiende a Teresa (camilla 2)','10','Interno')
    camilla(ax,0.6,5.2,1,'Ramiro (estable)',1.0,barcol='#bbb')
    camilla(ax,0.6,1.4,2,'Teresa 39,5 °C',0.55,barcol='#444')
    ax.text(3.2,1.9,'↓↓ baja\nrápido',fontsize=7)
    fig_person(ax,6.0,2.8,'Walter',bata=True)
    caja(ax,8.6,0.6,3.0,1.4,'MOSTRADOR\nhoja de triaje',fc='#fff',fs=6.5)
    fig_person(ax,10.1,3.0,'Lucía')
    bocadillo(ax,6.6,5.3,'Lucía: «Doctor, ¿me firma la hoja de triaje cuando pueda?» (opcional, +1 confianza)',w=5.0)
    ax.text(6.0,0.25,'¿Teresa primero o el triaje?',ha='center',fontsize=7,style='italic')
def V05(ax):
    hud(ax,'Ayuda a Lucía con el carro','20','Interno · Confianza 1')
    caja(ax,0.4,1.0,3.6,3.2,'CARRO DE\nMEDICAMENTOS\ncajones 1 · 2 · 3',fs=6.5)
    caja(ax,9.2,1.0,2.4,2.4,'BOTIQUÍN\nROJO\n[cerrado]',fc='#bbb',fs=7)
    fig_person(ax,5.2,1.3,'Walter',bata=True); fig_person(ax,7.4,1.3,'Lucía')
    flecha(ax,4.6,2.6,-0.5,0)
    bocadillo(ax,0.6,5.3,'Lucía: «Llevo doble turno… Gracias, doctor. El código del botiquín rojo es 4-1-7. Lo vas a necesitar».',w=7.0)
    ax.text(10.4,4.0,'→ se abrirá',ha='center',fontsize=7)
def V06(ax):
    hud(ax,'Estabiliza a Andrés (camilla 3)','20','Confianza 2')
    caja(ax,0.3,0.4,1.6,2.2,'ENTRADA\nAMBU-\nLANCIAS',fc='#fff',fs=6.0)
    ax.text(1.1,2.9,'((( SIRENA )))',ha='center',fontsize=7,weight='bold')
    camilla(ax,2.6,1.0,3,'Andrés',0.5,barcol='#222')
    ax.text(4.6,3.05,'ronchas · le cuesta respirar',ha='center',fontsize=6.3)
    ax.text(5.15,1.95,'¡Crítico!',fontsize=7,weight='bold')
    camilla(ax,8.8,6.0,2,'Teresa (observación)',0.7,barcol='#666')
    ax.text(10.0,5.25,'congelada si confianza = 2',fontsize=6,ha='center',style='italic')
    fig_person(ax,6.8,0.9,'Walter',bata=True); fig_person(ax,10.6,1.6,'Lucía')
    bocadillo(ax,0.4,5.6,'Lucía: «Yo me quedo con Teresa, ve tú».',w=4.2)
def V07(ax):
    hud(ax,'Estabiliza a Andrés (camilla 3)','20','Confianza 2')
    caja(ax,8.8,4.4,2.8,2.6,'BOTIQUÍN ROJO\n[abierto]\nepinefrina ×1',fc='#ddd',fs=6.5)
    camilla(ax,0.8,1.6,3,'Andrés',0.25,barcol='#222')
    fig_person(ax,6.4,2.0,'Walter (carga epinefrina)',bata=True)
    caja(ax,5.75,4.25,1.3,0.45,'epinefrina',fc='#fff',fs=5.5)
    flecha(ax,8.7,5.3,-1.6,-0.8); flecha(ax,5.6,2.5,-2.2,0)
    ax.text(0.6,5.6,'Diagnóstico elegido:\nReacción alérgica grave ✓',fontsize=7)
def V08(ax):
    hud(ax,'Elige tu capacitación','35','Rango: Residente')
    fig_person(ax,1.4,1.0,'Dr. Salgado',bata=True); fig_person(ax,3.4,1.0,'Walter',bata=True)
    caja(ax,5.0,0.8,6.6,6.8,'',fc='#f0f0f0',lw=2)
    ax.text(8.3,6.9,'TABLÓN · CAPACITACIONES',ha='center',fontsize=8,weight='bold')
    for i,t in enumerate(['Urgencias','Pediatría','Cirugía']): caja(ax,5.8,5.3-i*1.5,5.0,1.0,t,fc='#fff')
    bocadillo(ax,0.3,4.6,'Salgado: «Así se trabaja en Pillbox. Elige tu capacitación».',w=4.4)

panels=[
 ('V01 / ESC-01 / B1 · gameplay',V01,'Cámara cenital: puerta, Salgado, tablón y camilla 1 en un encuadre.','Jugador: entra y se mueve (conserva control). Sistema: diálogo + intro_vista = true + objetivo en HUD.','Ambiente de hospital; diálogo también en texto.','Pasa a V02 al pulsar E junto a la camilla 1. Al volver a la puerta no se repite la bienvenida.'),
 ('V02 / ESC-01 / B2 · gameplay',V02,'Cámara sobre camilla 1; panel a la derecha sin tapar la barra.','Jugador: examina y elige 1 de 3. Sistema: muestra signos; si falla, estabilidad −10.','«Bip» al abrir panel; SFX grave + borde rojo si falla.','Pasa a V03 con diagnóstico correcto. Si falla: reintenta en el mismo panel.'),
 ('V03 / ESC-01 / B2 · gameplay',V03,'Botiquín A y camilla 1 visibles a la vez.','Jugador: toma vendaje, lo aplica. Sistema: estabilidad 100, caso_ramiro_resuelto = true, rep. +10.','Tono de confirmación + barra llena.','Pasa a V04 3 s después (entra Teresa). Insumo incorrecto: se pierde, se vuelve al botiquín.'),
 ('V04 / B3 · gameplay',V04,'Plano amplio: dos camillas + mostrador.','Jugador: decide orden (Teresa / triaje). Sistema: barra de Teresa baja 1/s.','Murmullo de sala más intenso; texto de Lucía.','Pasa a V05 cuando Teresa queda en observación (o transferida). Triaje opcional: confianza +1.'),
 ('V05 / B4 · gameplay (respiro)',V05,'Carro de medicamentos y botiquín rojo cerrado en el mismo plano.','Jugador: ordena 3 insumos. Sistema: ayuda_lucia = true, confianza +1, botiquin_rojo_abierto = true.','Música baja; diálogo en texto.','Pasa a V06 al terminar TimerAmbulancia (10 s). Si se equivoca de cajón, el insumo vuelve al carro.'),
 ('V06 / ESC-02 / B5 · gameplay',V06,'Entrada de ambulancias, camilla 3 y Teresa visibles.','Jugador: va a examinar a Andrés. Sistema: barra de Andrés −3/s; Teresa congelada si confianza = 2.','Sirena posicional (izquierda); latido si barra < 30; borde rojo.','Pasa a V07 con diagnóstico correcto. Si confianza < 2, Teresa sigue bajando 0,5/s.'),
 ('V07 / ESC-02 / B5 · gameplay',V07,'Botiquín rojo y camilla 3 en un solo encuadre.','Jugador: toma epinefrina (1 dosis) y la aplica. Sistema: caso_andres_resuelto = true, rep. +15.','Tono de confirmación; se apaga el latido.','Pasa a V08 si reputación ≥ 30. Si la barra llega a 0: reinicio en punto de control de B5.'),
 ('V08 / ESC-02 / B6 · gameplay',V08,'Plano del tablón ahora habilitado (gris → dorado).','Jugador: elige Urgencias, Pediatría o Cirugía. Sistema: especialidad asignada, rango = "Residente".','Fanfarria corta; texto de rango en HUD.','Fin del nivel. Si reputación < 30: «Repite el turno» desde B3. El panel no se abre dos veces.'),
]

def render(ax_img,ax_txt,p):
    title,fn,cam,acc,aud,tr=p
    ax_img.set_xlim(0,12); ax_img.set_ylim(0,10); ax_img.set_aspect('equal'); ax_img.axis('off')
    ax_img.add_patch(Rectangle((0,0),12,10,fill=False,ec='#000',lw=2.2))
    fn(ax_img); ax_img.set_title(title,fontsize=9.5,weight='bold',loc='left')
    ax_txt.axis('off')
    rows=[('Encuadre',cam),('Acción',acc),('Audio/señal',aud),('Transición',tr)]
    y=0.97
    for k,v in rows:
        lines=textwrap.wrap(v,60)
        ax_txt.text(0.0,y,k+':',fontsize=7.2,weight='bold',va='top',transform=ax_txt.transAxes)
        ax_txt.text(0.2,y,'\n'.join(lines),fontsize=7.2,va='top',transform=ax_txt.transAxes)
        y-=0.105*len(lines)+0.05

def page(idx,fname=None,pdf=None):
    fig=plt.figure(figsize=(11,11),dpi=160)
    fig.suptitle('Bata Blanca: Hospital de Pillbox — Nivel 1 «La primera guardia» · Storyboard de gameplay (Propuesto)',fontsize=11)
    gs=fig.add_gridspec(4,2,height_ratios=[3,1.5,3,1.5],hspace=0.15,wspace=0.08,left=0.03,right=0.97,top=0.92,bottom=0.02)
    for k,i in enumerate(idx):
        r=(k//2)*2; c=k%2
        render(fig.add_subplot(gs[r,c]),fig.add_subplot(gs[r+1,c]),panels[i])
    if pdf: pdf.savefig(fig)
    if fname: fig.savefig(fname)
    plt.close(fig)

out='../'
with PdfPages(out+'04_storyboard.pdf') as pdf:
    page([0,1,2,3],out+'04_storyboard_p1.png',pdf)
    page([4,5,6,7],out+'04_storyboard_p2.png',pdf)
print('ok')
