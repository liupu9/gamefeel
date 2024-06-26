// 游戏实体
class Entity {
    // 固定大小的实体数组
	public static var ALL : FixedArray<Entity> = new FixedArray(1024);
    public static var GC : FixedArray<Entity> = new FixedArray(ALL.maxSize);

	// 实体可以方便获取各种游戏内的数据、实例（共享），相当于封装了一些get方法。
	// Various getters to access all important stuff easily
	public var app(get,never) : App; inline function get_app() return App.ME;
	public var game(get,never) : Game; inline function get_game() return Game.ME;
	public var fx(get,never) : Fx; inline function get_fx() return Game.ME.fx;
	public var level(get,never) : Level; inline function get_level() return Game.ME.level;
	public var destroyed(default,null) = false;
	public var ftime(get,never) : Float; inline function get_ftime() return game.ftime;
	public var camera(get,never) : Camera; inline function get_camera() return game.camera;
	public var options(get,never) : Options; inline function get_options() return App.ME.options;
	public var hero(get,never) : en.Hero; inline function get_hero() return Game.ME.hero;

	var tmod(get,never) : Float; inline function get_tmod() return Game.ME.tmod;
	var utmod(get,never) : Float; inline function get_utmod() return Game.ME.utmod;
	public var hud(get,never) : ui.Hud; inline function get_hud() return Game.ME.hud;

	/** Cooldowns 一般冷却 **/
	public var cd : dn.Cooldown;

	/** Cooldowns, 不受敌方迟顿影响的冷却 unaffected by slowmo (ie. always in realtime) **/
	public var ucd : dn.Cooldown;

	/** 临时影响 Temporary gameplay affects **/
	var affects : Map<Affect,Float> = new Map();

	/** 状态机 State machine. Value should only be changed using `startState(v)` **/
	public var state(default,null) : State;

	/** 唯一ID Unique identifier **/
	public var uid(default,null) : Int;

	/** 格子坐标X Grid X coordinate **/
    public var cx = 0;
	/** 格子坐标Y Grid Y coordinate **/
    public var cy = 0;
	/** 一个格子内坐标X Sub-grid X coordinate (from 0.0 to 1.0) **/
    public var xr = 0.5;
	/** 一个格子内坐标Y Sub-grid Y coordinate (from 0.0 to 1.0) **/
    public var yr = 1.0;

	/**
		是否落地？判断条件:
		1. yr = 1
		2. 判断是否碰撞（cx, cy+1）
		3. 向下的速度 vBase.dy > 0
	 **/
	public var onGround(get,never) : Bool;
		inline function get_onGround() return yr==1 && level.hasCollision(cx,cy+1) && vBase.dy>=0;

	/**
		多个速度的数组，用于计算最终的速度值。
	**/
	var allVelocities : VelocityArray;

	/** “用户控制”的基本速度 Base X/Y velocity of the Entity **/
	public var vBase : Velocity;
	/**
		“外部碰撞”速度。它用于将实体推向某个方向，独立于“用户控制”的基本速度
		"External bump" velocity. It is used to push the Entity in some direction, independently of the "user-controlled" base velocity. 
	**/
	public var vBump : Velocity;

	/**
		在最近一次固定更新点（fixedUpdate）的开始处，附加点的最后已知X位置(以像素为单位)
		Last known X position of the attach point (in pixels), at the beginning of the latest fixedUpdate
	**/
	var lastFixedUpdateX = 0.;
	/** 
		在最近一次固定更新点（fixedUpdate）的开始处，附加点的最后已知Y位置(以像素为单位)
		Last known Y position of the attach point (in pixels), at the beginning of the latest fixedUpdate
	**/
	var lastFixedUpdateY = 0.;

	/**
		精灵插值位置开关：如果为TRUE，则精灵显示坐标将是最后一个已知位置和当前位置之间的插值。
		If TRUE, the sprite display coordinates will be an interpolation between the last known position and the current one.
		This is useful if the gameplay happens in the `fixedUpdate()` (so at 30 FPS), but you still want the sprite position 
		to move smoothly at 60 FPS or more.
	**/
	var interpolateSprPos = true;

	/**
		掉落开始的Y坐标值（像素）
	**/
	var fallStartPxY = 0.;
	/**
		是否和墙发生碰撞？
	**/
	var collidesWithWalls = true;

	/** X方向的总速度值 Total of all X velocities **/
	public var dxTotal(get,never) : Float; inline function get_dxTotal() return allVelocities.getSumX();
	/** Y方向的总速度值 Total of all Y velocities **/
	public var dyTotal(get,never) : Float; inline function get_dyTotal() return allVelocities.getSumY();

	/** 实体的像素宽度 Pixel width of entity **/
	public var wid(default,set) : Float = Const.GRID;
		inline function set_wid(v) { invalidateDebugBounds=true;  return wid=v; }
	public var iwid(get,set) : Int;
		inline function get_iwid() return M.round(wid);
		inline function set_iwid(v:Int) { invalidateDebugBounds=true; wid=v; return iwid; }

	/** 实体的像素高度 Pixel height of entity **/
	public var hei(default,set) : Float = Const.GRID;
		inline function set_hei(v) { invalidateDebugBounds=true;  return hei=v; }
	public var ihei(get,set) : Int;
		inline function get_ihei() return M.round(hei);
		inline function set_ihei(v:Int) { invalidateDebugBounds=true; hei=v; return ihei; }

	/** 内部半径（像素值）：最小边长的一半 Inner radius in pixels (ie. smallest value between width/height, then divided by 2) **/
	public var innerRadius(get,never) : Float;
		inline function get_innerRadius() return M.fmin(wid,hei)*0.5;

	/** 大半径（像素值）：最大边长的一半 "Large" radius in pixels (ie. biggest value between width/height, then divided by 2) **/
	public var largeRadius(get,never) : Float;
		inline function get_largeRadius() return M.fmax(wid,hei)*0.5;

	/** 水平方向 只能为-1或1 Horizontal direction, can only be -1 or 1 **/
	public var dir(default,set) = 1;

	/** 精灵当前X坐标（计算插值） Current sprite X **/
	public var sprX(get,never) : Float;
		inline function get_sprX() {
			return interpolateSprPos
				? M.lerp( lastFixedUpdateX, (cx+xr)*Const.GRID, game.getFixedUpdateAccuRatio() )
				: (cx+xr)*Const.GRID;
		}

	/** 精灵当前Y坐标（计算插值） Current sprite Y **/
	public var sprY(get,never) : Float;
		inline function get_sprY() {
			return interpolateSprPos
				? M.lerp( lastFixedUpdateY, (cy+yr)*Const.GRID, game.getFixedUpdateAccuRatio() )
				: (cy+yr)*Const.GRID;
		}

	/** 精灵X坐标缩放 Sprite X scaling **/
	public var sprScaleX = 1.0;
	/** 精灵Y坐标缩放 Sprite Y scaling **/
	public var sprScaleY = 1.0;

	/** 精灵X坐标 压缩和拉伸缩放，在几帧后自动返回1.0 
		Sprite X squash & stretch scaling, which automatically comes back to 1 after a few frames **/
	var sprSquashX = 1.0;
	/** 精灵Y坐标 压缩和拉伸缩放，在几帧后自动返回1.0
		Sprite Y squash & stretch scaling, which automatically comes back to 1 after a few frames **/
	var sprSquashY = 1.0;

	/** 精灵X坐标补偿 **/
	var sprOffsetX = 0.;

	/** 实体是否可见？ Entity visibility **/
	public var entityVisible = true;

	/** 状态：当前生命值 Current hit points **/
	public var life(default,null) : dn.struct.Stat<Int>;
	/** 最近一次伤害来源（实体） Last source of damage if it was an Entity **/
	public var lastDmgSource(default,null) : Null<Entity>;

	/** 最近一次攻击源的水平方向（攻击源实体 -> 自身实体）
		Horizontal direction (left=-1 or right=1): from "last source of damage" to "this" **/
	public var lastHitDirFromSource(get,never) : Int;
	inline function get_lastHitDirFromSource() return lastDmgSource==null ? -dir : -dirTo(lastDmgSource);

	/** 最近一次水平攻击方向 (自身实体 -> 被攻击实体)
		Horizontal direction (left=-1 or right=1): from "this" to "last source of damage" **/
	public var lastHitDirToSource(get,never) : Int;
		inline function get_lastHitDirToSource() return lastDmgSource==null ? dir : dirTo(lastDmgSource);

	/** 主实体的精灵实例 Main entity HSprite instance **/
    public var spr : HSprite;

	/** 精灵的颜色向量变化 Color vector transformation applied to sprite **/
	public var baseColor : h3d.Vector;

	/** 精灵的颜色矩阵变化 Color matrix transformation applied to sprite **/
	public var colorMatrix : h3d.Matrix;

	// 受到伤害时的动画闪烁颜色 Animated blink color on damage hit
	var blinkColor : h3d.Vector;

	/** 精灵X震动力 Sprite X shake power **/
	var shakePowX = 0.;
	/** 精灵Y震动力 Sprite Y shake power **/
	var shakePowY = 0.;

	// 调试用 Debug stuff
	var debugLabel : Null<h2d.Text>;
	var debugBounds : Null<h2d.Graphics>;
	var invalidateDebugBounds = false;
	// 弹出xx
	var popTf : Null<h2d.Text>;

	/** 定义实体在其附加点处的X对齐方式 Defines X alignment of entity at its attach point (0 to 1.0) **/
	public var pivotX(default,set) : Float = 0.5;
	/** 定义实体在其附加点处的Y对齐方式 Defines Y alignment of entity at its attach point (0 to 1.0) **/
	public var pivotY(default,set) : Float = 1;

	/** 实体附加点X坐标 Entity attach X pixel coordinate **/
	public var attachX(get,never) : Float; inline function get_attachX() return (cx+xr)*Const.GRID;
	/** 实体附加点Y坐标 Entity attach Y pixel coordinate **/
	public var attachY(get,never) : Float; inline function get_attachY() return (cy+yr)*Const.GRID;

	// 各种获取坐标的getter方法，为了使游戏玩法更好编码实现 Various coordinates getters, for easier gameplay coding

	/** Left pixel coordinate of the bounding box **/
	public var left(get,never) : Float; inline function get_left() return attachX + (0-pivotX) * wid;
	/** Right pixel coordinate of the bounding box **/
	public var right(get,never) : Float; inline function get_right() return attachX + (1-pivotX) * wid;
	/** Top pixel coordinate of the bounding box **/
	public var top(get,never) : Float; inline function get_top() return attachY + (0-pivotY) * hei;
	/** Bottom pixel coordinate of the bounding box **/
	public var bottom(get,never) : Float; inline function get_bottom() return attachY + (1-pivotY) * hei;

	/** Center X pixel coordinate of the bounding box **/
	public var centerX(get,never) : Float; inline function get_centerX() return attachX + (0.5-pivotX) * wid;
	/** Center Y pixel coordinate of the bounding box **/
	public var centerY(get,never) : Float; inline function get_centerY() return attachY + (0.5-pivotY) * hei;

	/** Current X position on screen (ie. absolute)**/
	public var screenAttachX(get,never) : Float;
		inline function get_screenAttachX() return game!=null && !game.destroyed ? sprX*Const.SCALE + game.scroller.x : sprX*Const.SCALE;

	/** Current Y position on screen (ie. absolute)**/
	public var screenAttachY(get,never) : Float;
		inline function get_screenAttachY() return game!=null && !game.destroyed ? sprY*Const.SCALE + game.scroller.y : sprY*Const.SCALE;

	/** attachX value during last frame **/
	public var prevFrameAttachX(default,null) : Float = -Const.INFINITE;
	/** attachY value during last frame **/
	public var prevFrameAttachY(default,null) : Float = -Const.INFINITE;

	/** 基于可回收对象池的受控动作 **/
	var actions : RecyclablePool<tools.ChargedAction>;


	/**
		Constructor
	**/
    public function new(x:Int, y:Int) {
        uid = Const.makeUniqueId();
		ALL.push(this); // 加入实体数组

		cd = new dn.Cooldown(Const.FPS);
		ucd = new dn.Cooldown(Const.FPS);
		life = new Stat();
        setPosCase(x,y);
		initLife(1);
		state = Normal;
		actions = new RecyclablePool(15, ()->new tools.ChargedAction());

		// 速度数组容器大小：15
		allVelocities = new VelocityArray(15);
		vBase = registerNewVelocity(0.9);
		vBump = registerNewVelocity(0.93);

		// 精灵
        spr = new HSprite(Assets.tiles);
		// 加入显示容器中
		Game.ME.scroller.add(spr, Const.DP_MAIN);
		spr.colorAdd = new h3d.Vector();
		baseColor = new h3d.Vector();
		blinkColor = new h3d.Vector();
		spr.colorMatrix = colorMatrix = h3d.Matrix.I();
		spr.setCenterRatio(pivotX, pivotY);

		if( ui.Console.ME.hasFlag(F_Bounds) )
			enableDebugBounds();
    }

	/** 注册新的速度，附带摩擦参数 **/
	public function registerNewVelocity(frict:Float) : Velocity {
		var v = Velocity.createFrict(frict);
		allVelocities.push(v);
		return v;
	}


	/** 从显示上下文删除精灵。 Remove sprite from display context. Only do that if you're 100% sure your entity won't need the `spr` instance itself. **/
	function noSprite() {
		spr.setEmptyTexture();
		spr.remove();
	}


	function set_pivotX(v) {
		pivotX = M.fclamp(v,0,1);
		if( spr!=null )
			spr.setCenterRatio(pivotX, pivotY);
		return pivotX;
	}

	function set_pivotY(v) {
		pivotY = M.fclamp(v,0,1);
		if( spr!=null )
			spr.setCenterRatio(pivotX, pivotY);
		return pivotY;
	}

	/** Initialize current and max hit points **/
	public function initLife(v) {
		life.initMaxOnMax(v);
	}

	/** Inflict damage **/
	public function hit(dmg:Int, from:Null<Entity>) {
		if( !isAlive() || dmg<=0 )
			return;

		life.v -= dmg;
		lastDmgSource = from;
		onDamage(dmg, from);
		if( life.v<=0 )
			onDie();
	}

	/** Kill instantly **/
	public function kill(by:Null<Entity>) {
		if( isAlive() )
			hit(life.v, by);
	}

	function onDamage(dmg:Int, from:Entity) {}

	function onDie() {
		destroy();
	}

	inline function set_dir(v) {
		return dir = v>0 ? 1 : v<0 ? -1 : dir;
	}

	/** Return TRUE if current entity wasn't destroyed or killed **/
	public inline function isAlive() {
		return !destroyed && life.v>0;
	}

	/** 移动实体到某个格子坐标 Move entity to grid coordinates **/
	public function setPosCase(x:Int, y:Int) {
		cx = x;
		cy = y;
		xr = 0.5;
		yr = 1;
		onPosManuallyChangedBoth();
	}

	/** 移动实体到某个像素位置（精确） Move entity to pixel coordinates **/
	public function setPosPixel(x:Float, y:Float) {
		cx = Std.int(x/Const.GRID);
		cy = Std.int(y/Const.GRID);
		xr = (x-cx*Const.GRID)/Const.GRID;
		yr = (y-cy*Const.GRID)/Const.GRID;
		onPosManuallyChangedBoth();
	}

	/** 当你手动修改（不考虑物理）XY坐标时，需要调用这个函数。
		Should be called when you manually (ie. ignoring physics) modify both X & Y entity coordinates **/
	function onPosManuallyChangedBoth() {
		// 当(attachX, attachY) (prevFrameAttachX, prevFrameAttachY) 两个点之间的距离 大于 两个格子的距离
		if( M.dist(attachX,attachY,prevFrameAttachX,prevFrameAttachY) > Const.GRID*2 ) {
			prevFrameAttachX = attachX;
			prevFrameAttachY = attachY;
		}
		updateLastFixedUpdatePos();
	}

	/** Should be called when you manually (ie. ignoring physics) modify entity X coordinate **/
	function onPosManuallyChangedX() {
		// 当X坐标移动的距离 大于 两个格子的距离
		if( M.fabs(attachX-prevFrameAttachX) > Const.GRID*2 )
			prevFrameAttachX = attachX;
		lastFixedUpdateX = attachX;
	}

	/** Should be called when you manually (ie. ignoring physics) modify entity Y coordinate **/
	function onPosManuallyChangedY() {
		// 当Y坐标移动的距离 大于 两个格子的距离
		if( M.fabs(attachY-prevFrameAttachY) > Const.GRID*2 )
			prevFrameAttachY = attachY;
		lastFixedUpdateY = attachY;
	}


	/** Quickly set X/Y pivots. If Y is omitted, it will be equal to X. **/
	public function setPivots(x:Float, ?y:Float) {
		pivotX = x;
		pivotY = y!=null ? y : x;
	}

	/** Return TRUE if the Entity *center point* is in screen bounds (default padding is +32px) **/
	public inline function isOnScreenCenter(padding=32) {
		return camera.isOnScreen( centerX, centerY, padding + M.fmax(wid*0.5, hei*0.5) );
	}

	/** Return TRUE if the Entity rectangle is in screen bounds (default padding is +32px) **/
	public inline function isOnScreenBounds(padding=32) {
		return camera.isOnScreenRect( left,top, wid, hei, padding );
	}


	/**
		Changed the current entity state.
		Return TRUE if the state is `s` after the call.
	**/
	public function startState(s:State) : Bool {
		if( s==state )
			return true;

		if( !canChangeStateTo(state, s) )
			return false;

		var old = state;
		state = s;
		onStateChange(old,state);
		return true;
	}


	/** Return TRUE to allow a change of the state value **/
	function canChangeStateTo(from:State, to:State) {
		return true;
	}

	/** Called when state is changed to a new value **/
	function onStateChange(old:State, newState:State) {}


	/** Apply a bump/kick force to entity **/
	public function bump(x:Float,y:Float) {
		vBump.addXY(x,y);
	}

	/** Reset velocities to zero **/
	public function cancelVelocities() {
		allVelocities.clearAll();
	}

	public function is<T:Entity>(c:Class<T>) return Std.isOfType(this, c);
	public function as<T:Entity>(c:Class<T>) : T return Std.downcast(this, c);

	/** Return a random Float value in range [min,max]. If `sign` is TRUE, returned value might be multiplied by -1 randomly. **/
	public inline function rnd(min,max,?sign) return Lib.rnd(min,max,sign);
	/** Return a random Integer value in range [min,max]. If `sign` is TRUE, returned value might be multiplied by -1 randomly. **/
	public inline function irnd(min,max,?sign) return Lib.irnd(min,max,sign);

	/** Truncate a float value using given `precision` **/
	public inline function pretty(value:Float,?precision=1) return M.pretty(value,precision);

	public inline function dirTo(e:Entity) return e.centerX<centerX ? -1 : 1;
	public inline function dirToAng() return dir==1 ? 0. : M.PI;
	public inline function getMoveAng() return Math.atan2(dyTotal,dxTotal);

	/** Return a distance (in grid cells) from this to something **/
	public inline function distCase(?e:Entity, ?tcx:Int, ?tcy:Int, txr=0.5, tyr=0.5) {
		if( e!=null )
			return M.dist(cx+xr, cy+yr, e.cx+e.xr, e.cy+e.yr);
		else
			return M.dist(cx+xr, cy+yr, tcx+txr, tcy+tyr);
	}

	/** Return a distance (in pixels) from this to something **/
	public inline function distPx(?e:Entity, ?x:Float, ?y:Float) {
		if( e!=null )
			return M.dist(attachX, attachY, e.attachX, e.attachY);
		else
			return return M.dist(attachX, attachY, x, y);
	}

	function canSeeThrough(cx:Int, cy:Int) {
		return !level.hasCollision(cx,cy) || this.cx==cx && this.cy==cy;
	}

	/** Check if the grid-based line between this and given target isn't blocked by some obstacle **/
	public inline function sightCheck(?e:Entity, ?tcx:Int, ?tcy:Int) {
		if( e!=null)
			return e==this ? true : dn.Bresenham.checkThinLine(cx, cy, e.cx, e.cy, canSeeThrough);
		else
			return dn.Bresenham.checkThinLine(cx, cy, tcx, tcy, canSeeThrough);
	}

	/** Create a LPoint instance from current coordinates **/
	public inline function createPoint() return LPoint.fromCase(cx+xr,cy+yr);

	/** Create a LRect instance from current entity bounds **/
	public inline function createRect() return tools.LRect.fromPixels( Std.int(left), Std.int(top), Std.int(wid), Std.int(hei) );

    public final function destroy() {
        if( !destroyed ) {
            destroyed = true;
            GC.push(this);
        }
    }

    public function dispose() {
        ALL.remove(this);

		allVelocities.dispose();
		allVelocities = null;
		baseColor = null;
		blinkColor = null;
		colorMatrix = null;

		spr.remove();
		spr = null;

		if( debugLabel!=null ) {
			debugLabel.remove();
			debugLabel = null;
		}

		if( debugBounds!=null ) {
			debugBounds.remove();
			debugBounds = null;
		}

		cd.dispose();
		cd = null;

		ucd.dispose();
		ucd = null;
    }


	/** Print some numeric value below entity **/
	public inline function debugFloat(v:Float, c:Col=0xffffff) {
		debug( pretty(v), c );
	}


	public function popText(txt:String, col:Col=White) {
		if( popTf==null ) {
			popTf = new h2d.Text(Assets.fontPixel);
			game.scroller.add(popTf,Const.DP_UI);
		}

		popTf.text = txt;
		popTf.textColor = col;
		popTf.visible = true;
		popTf.alpha = 1;
		popTf.x = Std.int(attachX - popTf.textWidth*0.5);
		popTf.y = Std.int(top - popTf.textHeight - 4);

		cd.setS("keepPop", 0.5);
	}

	/** Print some value below entity **/
	public inline function debug(?v:Dynamic, c:Col=0xffffff) {
		#if debug
		if( v==null && debugLabel!=null ) {
			debugLabel.remove();
			debugLabel = null;
		}
		if( v!=null ) {
			if( debugLabel==null ) {
				debugLabel = new h2d.Text(Assets.fontPixel, Game.ME.scroller);
				debugLabel.filter = new dn.heaps.filter.PixelOutline();
			}
			debugLabel.text = Std.string(v);
			debugLabel.textColor = c;
		}
		#end
	}

	/** 隐藏实体调试框 Hide entity debug bounds **/
	public function disableDebugBounds() {
		if( debugBounds!=null ) {
			debugBounds.remove();
			debugBounds = null;
		}
	}


	/** Show entity debug bounds (position and width/height). Use the `/bounds` command in Console to enable them. **/
	public function enableDebugBounds() {
		if( debugBounds==null ) {
			debugBounds = new h2d.Graphics();
			game.scroller.add(debugBounds, Const.DP_TOP);
		}
		invalidateDebugBounds = true;
	}

	function renderDebugBounds() {
		var c = Col.fromHsl((uid%20)/20, 1, 1);
		debugBounds.clear();

		// Bounds rect
		debugBounds.lineStyle(1, c, 0.5);
		debugBounds.drawRect(left-attachX, top-attachY, wid, hei);

		// Attach point
		debugBounds.lineStyle(0);
		debugBounds.beginFill(c,0.8);
		debugBounds.drawRect(-1, -1, 3, 3);
		debugBounds.endFill();

		// Center
		debugBounds.lineStyle(1, c, 0.3);
		debugBounds.drawCircle(centerX-attachX, centerY-attachY, 3);
	}

	/** Wait for `sec` seconds, then runs provided callback. **/
	function chargeAction(id:ChargedActionId, sec:Float, onComplete:ChargedAction->Void, ?onProgress:ChargedAction->Void) {
		if( !isAlive() )
			return;

		if( isChargingAction(id) )
			cancelAction(id);

		var a = actions.alloc();
		a.id = id;
		a.onComplete = onComplete;
		a.durationS = sec;
		if( onProgress!=null )
			a.onProgress = onProgress;
	}

	/** If id is null, return TRUE if any action is charging. If id is provided, return TRUE if this specific action is charging now. **/
	public function isChargingAction(?id:ChargedActionId) {
		if( !isAlive() )
			return false;

		if( id==null )
			return actions.allocated>0;

		for(a in actions)
			if( a.id==id )
				return true;

		return false;
	}

	public function getChargeRatio(id:ChargedActionId) {
		if( !isAlive() )
			return 0.;

		for(a in actions)
			if( a.id==id )
				return a.elapsedRatio;
		return 0.;
	}

	public function cancelAction(?onlyId:ChargedActionId) {
		if( !isAlive() )
			return;

		if( onlyId==null )
			actions.freeAll();
		else {
			var i = 0;
			while( i<actions.allocated ) {
				if( actions.get(i).id==onlyId )
					actions.freeIndex(i);
				else
					i++;
			}
		}
	}

	/** Action management loop **/
	function updateActions() {
		if( !isAlive() )
			return;

		var i = 0;
		while( i<actions.allocated ) {
			if( actions.get(i).update(tmod) )
				actions.freeIndex(i);
			else
				i++;
		}
	}


	public inline function hasAffect(k:Affect) {
		return isAlive() && affects.exists(k) && affects.get(k)>0;
	}

	public inline function getAffectDurationS(k:Affect) {
		return hasAffect(k) ? affects.get(k) : 0.;
	}

	/** Add an Affect. If `allowLower` is TRUE, it is possible to override an existing Affect with a shorter duration. **/
	public function setAffectS(k:Affect, t:Float, allowLower=false) {
		if( !isAlive() || affects.exists(k) && affects.get(k)>t && !allowLower )
			return;

		if( t<=0 )
			clearAffect(k);
		else {
			var isNew = !hasAffect(k);
			affects.set(k,t);
			if( isNew )
				onAffectStart(k);
		}
	}

	/** Multiply an Affect duration by a factor `f` **/
	public function mulAffectS(k:Affect, f:Float) {
		if( hasAffect(k) )
			setAffectS(k, getAffectDurationS(k)*f, true);
	}

	public function clearAffect(k:Affect) {
		if( hasAffect(k) ) {
			affects.remove(k);
			onAffectEnd(k);
		}
	}

	/** Affects update loop **/
	function updateAffects() {
		if( !isAlive() )
			return;

		for(k in affects.keys()) {
			var t = affects.get(k);
			t-=1/Const.FPS * tmod;
			if( t<=0 )
				clearAffect(k);
			else
				affects.set(k,t);
		}
	}

	function onAffectStart(k:Affect) {}
	function onAffectEnd(k:Affect) {}

	/** Return TRUE if the entity is active and has no status affect that prevents actions. **/
	public function isConscious() {
		return !hasAffect(Stun) && isAlive();
	}

	/** Blink `spr` briefly (eg. when damaged by something) **/
	public function blink(c:Col) {
		blinkColor.setColor(c);
		cd.setS("keepBlink",0.06);
	}

	public function shakeS(xPow:Float, yPow:Float, t:Float) {
		cd.setS("shaking", t, true);
		shakePowX = xPow;
		shakePowY = yPow;
	}

	/** Briefly squash sprite on X (Y changes accordingly). "1.0" means no distorsion. **/
	public function setSquashX(scaleX:Float) {
		sprSquashX = scaleX;
		sprSquashY = 2-scaleX;
	}

	/** Briefly squash sprite on Y (X changes accordingly). "1.0" means no distorsion. **/
	public function setSquashY(scaleY:Float) {
		sprSquashX = 2-scaleY;
		sprSquashY = scaleY;
	}


	/**
		“帧的开始”循环，在任何其他实体更新循环之前调用
		"Beginning of the frame" loop, called before any other Entity update loop
	**/
    public function preUpdate() {
		ucd.update(utmod);
		cd.update(tmod);
		updateAffects();
		updateActions();


		#if debug
		// Show bounds (with `/bounds` in console)
		if( ui.Console.ME.hasFlag(F_Bounds) && debugBounds==null )
			enableDebugBounds();

		// Hide bounds
		if( !ui.Console.ME.hasFlag(F_Bounds) && debugBounds!=null )
			disableDebugBounds();
		#end

    }

	/**
		后更新循环，保证在任何预更新/更新之后发生。这通常是渲染和显示更新的地方
		Post-update loop, which is guaranteed to happen AFTER any preUpdate/update. This is usually where render and display is updated
	**/
    public function postUpdate() {
        // 更新精灵的x坐标，考虑到偏移量
        spr.x = sprX + sprOffsetX;
        // 更新精灵的y坐标
        spr.y = sprY;   
        // 根据方向、缩放比例和挤压因子更新精灵的x轴缩放
        spr.scaleX = dir * sprScaleX * sprSquashX;
        // 更新精灵的y轴缩放
        spr.scaleY = sprScaleY * sprSquashY;
        // 设置精灵的可见性
        spr.visible = entityVisible;

        // 基于tmod更新sprSquashX，模拟弹性效果
        sprSquashX += (1-sprSquashX) * M.fmin(1, 0.2*tmod);
        // 基于tmod更新sprSquashY，模拟弹性效果
        sprSquashY += (1-sprSquashY) * M.fmin(1, 0.2*tmod);

        // 根据tmod减少sprOffsetX，可能用于模拟衰减效果
        sprOffsetX *= Math.pow(0.8,tmod);

        // 检查是否有“抖动”（shaking）效果
        if( cd.has("shaking") ) {
            // 添加基于时间的x轴抖动效果
            spr.x += Math.cos(ftime*1.1)*shakePowX * cd.getRatio("shaking");
            // 添加基于时间的y轴抖动效果
            spr.y += Math.sin(0.3+ftime*1.7)*shakePowY * cd.getRatio("shaking");
        }

        // 处理闪烁效果（Blink）
        if(!cd.has("keepBlink") ) {
            // 基于时间减少红色分量，以实现淡出效果
            blinkColor.r*=Math.pow(0.60, tmod);
            // 基于时间减少绿色分量
            blinkColor.g*=Math.pow(0.55, tmod);
            // 基于时间减少蓝色分量
            blinkColor.b*=Math.pow(0.50, tmod);
        }

        // 颜色叠加处理
        // 加载基本颜色到精灵的颜色叠加属性
        spr.colorAdd.load(baseColor);
        // 根据闪烁颜色值更新颜色叠加的红色分量
        spr.colorAdd.r += blinkColor.r;
        // 根据闪烁颜色值更新颜色叠加的绿色分量
        spr.colorAdd.g += blinkColor.g;
        // 根据闪烁颜色值更新颜色叠加的蓝色分量
        spr.colorAdd.b += blinkColor.b;

        // 调试标签处理
        if( debugLabel!=null ) {
            // 将调试标签水平居中放置在attachX位置
            debugLabel.x = Std.int(attachX - debugLabel.textWidth*0.5);
            // 将调试标签放置在attachY+1位置
            debugLabel.y = Std.int(attachY+1);
        }

        // 调试边界处理
        if( debugBounds!=null ) {
            // 如果需要更新调试边界
            if( invalidateDebugBounds ) {
                // 重置更新标志
                invalidateDebugBounds = false;
                // 渲染调试边界
                renderDebugBounds();
            }
            // 设置调试边界的x坐标
            debugBounds.x = Std.int(attachX);
            // 设置调试边界的y坐标
            debugBounds.y = Std.int(attachY);
        }

        // 淡出文本弹出效果处理
        if( popTf!=null && popTf.visible && !cd.has("keepPop") ) {
            // 根据时间减少弹出文本的透明度
            popTf.alpha -= 0.05*tmod;
            // 如果透明度小于等于0，则隐藏文本
            if( popTf.alpha<=0 ) {
                popTf.visible = false;
                // 将透明度重置为1，准备下次显示
                popTf.alpha = 1;
            }
        }
    }

	/**
		在帧的绝对末端运行的循环 Loop that runs at the absolute end of the frame
	**/
	public function finalUpdate() {
		prevFrameAttachX = attachX;
		prevFrameAttachY = attachY;
	}


	/**
		将当前附加点的位置坐标 保存到 上一个固定更新坐标
	**/
	final function updateLastFixedUpdatePos() {
		lastFixedUpdateX = attachX;
		lastFixedUpdateY = attachY;
	}

	/** 获取重力加速度 **/
	function getGravityMul() return 1.0;

	/** 落地行为，由子类根据实际情况实现，参数为掉落格子数 **/
	function onLand(cHei:Float) {}

	/**
		在每个X移动步骤开始前调用
		Called at the beginning of each X movement step
	**/
	function onPreStepX() {
		// 如果需要检测碰撞到墙
		if( collidesWithWalls ) {
			// Right collision 向右碰撞：水平偏移>0.8 且 右侧格子为碰撞格子
			if( xr>0.8 && level.hasCollision(cx+1,cy) )
				xr = 0.8; // 定格到这偏移量，不再继续靠近

			// Left collision 向左碰撞：水平偏移<0.2 且 左侧格子为碰撞格子
			if( xr<0.2 && level.hasCollision(cx-1,cy) )
				xr = 0.2; // 定格到这偏移量，不再继续靠近
		}
	}

	/**
		在每个Y移动步骤开始前调用
		Called at the beginning of each Y movement step
	**/
	function onPreStepY() {
		// 如果需要检测碰撞到墙
		if( collidesWithWalls ) {
			// Land on ground 落地碰撞：竖直偏移>=1 且 下侧格子为碰撞数据
			if( yr>=1 && level.hasCollision(cx,cy+1) ) {
				onLand( (attachY-fallStartPxY)/Const.GRID );
				vBase.dy = 0; // 基本速度的dy设置为0
				yr = 1; // 竖直偏移设置为1
				onPosManuallyChangedY();
				fallStartPxY = attachY;
			}

			// Ceiling collision 顶部碰撞：竖直偏移<0.6 且 上侧格子为碰撞格子
			if( yr<0.6 && level.hasCollision(cx,cy-1) ) {
				vBase.dy *= 0.5; // 基本速度的dy降速为之前的0.5倍
				yr = 0.6; // 竖直偏移固定为0.6不动
			}
		}
	}


	/**
		固定更新（帧）
		Main loop, but it only runs at a "guaranteed" 30 fps (so it might not be called during some frames, if the app runs at 60fps).
		This is usually where most gameplay elements affecting physics should occur, to ensure these will not depend on FPS at all.
	**/
	public function fixedUpdate() {
		updateLastFixedUpdatePos();

		// 如果未落地
		if( !onGround )
			vBase.dy += 0.05*getGravityMul(); // 基础速度每帧增加 0.05 ，相当于每秒 1.5格

		// 落地 或 Y方向速度<=0
		if( onGround || dyTotal<=0 )
			fallStartPxY = attachY;

		/*
			步进:任何大于网格尺寸33%的移动(0.33)会增加这里的“步骤”数。这些步骤将把整个移动分解成更小的迭代，以避免跳过网格碰撞。
			这里为什么采用0.33这个值？
			Stepping: any movement greater than 33% of grid size (ie. 0.33) will increase the number of `steps` here.
			These steps will break down the full movement into smaller iterations to avoid jumping over grid collisions.
		*/
		var steps = M.ceil( ( M.fabs(dxTotal) + M.fabs(dyTotal) ) / 0.33 );
		if( steps>0 ) {
			var n = 0;
			// 循环N次处理
			while ( n<steps ) {
				// X movement X轴分解为N分之一
				xr += dxTotal / steps;

				if( dxTotal!=0 ) onPreStepX(); // <---- Add X collisions checks and physics in here 碰撞检测和物理

				while( xr>1 ) { xr--; cx++; } // 同步格子
				while( xr<0 ) { xr++; cx--; }

				// Y movement Y轴分解为N分之一
				yr += dyTotal / steps;

				if( dyTotal!=0 ) onPreStepY(); // <---- Add Y collisions checks and physics in here 碰撞检测和物理

				while( yr>1 ) { yr--; cy++; } // 同步格子
				while( yr<0 ) { yr++; cy--; }

				n++;
			}
		}
		/**
			以上这段代码就像一个指挥官，它精确地控制对象在二维空间中的移动。通过 onPreStepX()和 onPreStepY() 函数，对象可以在每次
			移动前对【环境】作出反应，确保它不会穿越墙壁或其它障碍物。同时，xr和yr就像对象的私人秘书，记录它的每一次微小位移，使得cx和
			cy能够同步更新，从而在虚拟的游戏世界中准确地报告对象的位置。
			这样精细的控制逻辑确保了对象的移动是精确、有序且遵循物理规则的。
		**/

		// Update velocities 更新速度容器组
		for(v in allVelocities)
			v.fixedUpdate();
	}


	/**
		Main loop running at full FPS (ie. always happen once on every frames, after preUpdate and before postUpdate)
	**/
    public function frameUpdate() {
    }
}