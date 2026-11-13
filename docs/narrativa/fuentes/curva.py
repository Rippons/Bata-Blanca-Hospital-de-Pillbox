import matplotlib.pyplot as plt
b=["B1\nBienvenida","B2\nDon Ramiro","B3\nTeresa +\ntriaje","B4\nRespiro:\ncarro Lucía","B5\nAmbulancia:\nAndrés","B6\nCapacitación"]
t=[2,3,4,2,5,2]; d=[1,2,3,1,4,1]
fig,ax=plt.subplots(figsize=(11,5.5),dpi=150)
x=range(1,7)
ax.plot(x,t,'-o',color='#222',lw=2.5,ms=9,label='Tensión narrativa')
ax.plot(x,d,'--s',color='#888',lw=1.8,ms=7,label='Dificultad')
for i,v in zip(x,t): ax.annotate(str(v),(i,v),textcoords='offset points',xytext=(0,10),ha='center',fontsize=12,weight='bold')
ax.axvspan(3.6,4.4,color='#ddd',alpha=.6); ax.text(4,4.7,'respiro',ha='center',color='#555',fontsize=10)
ax.axvspan(4.6,5.4,color='#bbb',alpha=.5); ax.text(5,5.45,'clímax',ha='center',color='#333',fontsize=10)
for xs,l in [(1.5,'Acto I'),(3.5,'Acto II'),(5.5,'Acto III')]: ax.text(xs,0.35,l,ha='center',fontsize=10,color='#444')
for v in (2.5,4.5): ax.axvline(v,color='#aaa',lw=.8,ls=':')
ax.set_xticks(list(x)); ax.set_xticklabels(b,fontsize=9.5)
ax.set_ylim(0,5.9); ax.set_yticks(range(1,6)); ax.set_ylabel('1 = calma · 5 = máxima expectativa')
ax.set_title('Bata Blanca: Hospital de Pillbox — Nivel 1 «La primera guardia»: curva de tensión',fontsize=12)
ax.legend(loc='upper left',frameon=False); ax.spines[['top','right']].set_visible(False)
plt.tight_layout(); plt.savefig('../02_curva_tension.png')
