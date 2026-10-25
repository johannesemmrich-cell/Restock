import re,sys
cat=open('SmartCart/Services/AssignmentService+Category.swift',encoding='utf-8').read()
nf=open('SmartCart/Services/AssignmentService+NonFoodCategories.swift',encoding='utf-8').read()
def block(src,name):
    i=src.index('static let '+name); j=src.index('\n    ]',i)
    return src[i:j]
def lits(t): return re.findall(r'"((?:[^"\\]|\\.)*)"',t)
drug=set(lits(block(cat,'drugstoreKeywords'))); var=set(lits(block(cat,'varietyStoreKeywords'))); hw=set(lits(block(cat,'hardwareStoreKeywords'))); ends=lits(block(cat,'nonFoodCompoundEndings'))
cm=[]
for kws,c in re.findall(r'\(\[(.*?)\],\s*"([^"]+)"\)',block(cat,'categoryMap'),re.S):
    cm.append((lits(kws),c))
nfm=[]
for kws,c,g in re.findall(r'NonFoodEntry\(keywords: \[(.*?)\], category: "([^"]+)", storeGroup: (nil|"[a-z]+")\)',nf,re.S):
    nfm.append((lits(kws),c,None if g=='nil' else g.strip('"')))
nfe=re.findall(r'\("([^"]+)", "([^"]+)"\)',block(nf,'nonFoodCategoryEndings'))
def c_any(n,ks): return any(k in n for k in ks)
def detectHardware(n):
    if c_any(n,["bohrmaschine","schrauber","akkuschrauber","säge","schleifer","hammer","zange","schraubenzieher","cutter","feile"]): return "Werkzeug"
    if c_any(n,["schaufel","spaten","harke","rechen","hacke","rasenmäher","heckenschere","gartenschlauch","bewässer","gartenpumpe","komposttonne","regentonne"]): return "Garten"
    if c_any(n,["farbe","lack","lasur","tapete","malerrolle","pinsel","malerband","spachtel","grundierung","klarlack"]): return "Farbe & Lack"
    if c_any(n,["rohr","siphon","abfluss","dichtung","fitting","ventil","armatur","lichtschalter","kabelkanal"]): return "Sanitär"
    if c_any(n,["schrauben","schraube","dübel","nagel","bolzen","fliese","zement","gips","mörtel","laminat","parkett","dämmung","isolierung","silikon"]): return "Baumaterial"
    return "Werkzeug"
def detectVariety(n):
    if c_any(n,["ventilator","lüfter","heizlüfter","lampe","glühbirne","led","steckdose","verlängerungskabel","batterien","batterie","akku","ladekabel","ladegerät","kopfhörer","lautsprecher","fan","heater","lamp","bulb","batteries"]): return "Elektronik"
    if c_any(n,["kerze","teelicht","lichterkette","deko","dekoration","girlande","weihnacht","advent","halloween","ballon","candle","decoration"]): return "Dekoration"
    if c_any(n,["schraubenzieher","hammer","zange","bohrer","schrauben","dübel","kleber","screwdriver","drill"]): return "Werkzeug"
    if c_any(n,["notizbuch","ordner","kugelschreiber","stift","bleistift","klebeband","schere","notebook","pen","pencil","scissors","tape"]): return "Schreibwaren"
    if c_any(n,["spielzeug","puzzle","brettspiel","spielkarten","toy","board game"]): return "Spielzeug"
    if c_any(n,["tischdecke","kissen","kissenbezug","bettwäsche","handtuch","geschirrtuch"]): return "Textilien"
    if c_any(n,["topf","pfanne","kochtopf","schüssel","schneidebrett","pot","pan","bowl"]): return "Küchenausstattung"
    return "Haushaltswaren"
def detectDrug(n):
    if c_any(n,["shampoo","conditioner","duschgel","seife","deo","haarspray","shower","soap","hair"]): return "Körperpflege"
    if c_any(n,["waschmittel","spülmittel","reiniger","detergent","cleaning","handschuh","gloves"]): return "Reinigung"
    if c_any(n,["pflaster","paracetamol","ibuprofen","vitamin","medikament","medicine","plaster"]): return "Medikamente"
    if c_any(n,["windeln","babynahrung","baby","diapers"]): return "Babybedarf"
    return "Körperpflege"
def food(n):
    best=None
    for kws,c in cm:
        for k in kws:
            if k in n and (best is None or len(k)>len(best[0])): best=(k,c)
    return best
def nonfood(n):
    best=None
    for kws,c,g in nfm:
        for k in kws:
            if k in n and (best is None or len(k)>len(best[0])): best=(k,c,g)
    return best
def byending(n):
    w=n.strip().split(' ')[-1] if n.strip() else ''
    if len(w)<4: return None
    for e,c in nfe:
        if w.endswith(e) and len(w)>len(e): return c
    for e,c in nfe:
        if w==e and len(e)>=4: return c
    return None
def old_path(n):
    if c_any(n,hw): return detectHardware(n)
    if c_any(n,var) or any(n.endswith(e) for e in ends): return detectVariety(n)
    if c_any(n,drug): return detectDrug(n)
    f=food(n)
    return f[1] if f else None
def old(name):
    n=name.lower(); r=old_path(n); return r or "Lebensmittel"
def new(name):
    n=name.lower(); f=food(n); x=nonfood(n)
    if x:
        if f and len(f[0])>len(x[0]): return f[1]
        return x[1]
    r=old_path(n)
    if r: return r
    e=byending(n)
    return e or "Lebensmittel"
def group_new(name):
    n=name.lower(); x=nonfood(n); f=food(n)
    g=None
    if x and not (f and len(f[0])>len(x[0])): g=x[2] or 'grocery'
    if g=="hardware" or (g is None and c_any(n,hw)): return "hardware"
    if g=="variety" or (g is None and (c_any(n,var) or any(n.endswith(e) for e in ends))): return "variety"
    if g=="drugstore" or (g is None and c_any(n,drug)): return "drugstore"
    return "grocery"
def group_old(name):
    n=name.lower()
    if c_any(n,hw): return "hardware"
    if c_any(n,var) or any(n.endswith(e) for e in ends): return "variety"
    if c_any(n,drug): return "drugstore"
    return "grocery"
if __name__=='__main__':
    print("entries",len(nfm),"keywords",sum(len(k) for k,_,_ in nfm),"endings",len(nfe))
    # 1) food keywords as names: category must stay food (regression)
    changed=[]
    for kws,c in cm:
        for k in kws:
            if old(k)!=new(k): changed.append((k,old(k),new(k)))
    print("\n== food keywords whose category changed:",len(changed)); [print("  ",x) for x in changed]
    # 2) old store-type keyword lists: how many change
    ch2=[]
    for k in sorted(drug|var|hw):
        if old(k)!=new(k): ch2.append((k,old(k),new(k)))
    print("\n== old non-food keywords whose category changed:",len(ch2)); [print("  ",x) for x in ch2]
    # 3) store group changes for old keyword lists
    ch3=[(k,group_old(k),group_new(k)) for k in sorted(drug|var|hw) if group_old(k)!=group_new(k)]
    print("\n== store group changes:",len(ch3)); [print("  ",x) for x in ch3]
    # 4) realistic names
    names=open(sys.argv[1],encoding='utf-8').read().split('\n') if len(sys.argv)>1 else []
    print("\n== realistic names: old -> new")
    for nm in names:
        if not nm.strip(): continue
        o,n_=old(nm),new(nm); flag="" if o==n_ else "  <-- changed"
        print(f"  {nm:32s} {o:18s} {n_:18s} {group_new(nm):9s}{flag}")
