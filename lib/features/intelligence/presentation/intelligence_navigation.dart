import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_palette.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../../core/branch/branch_scope_provider.dart';
import 'intelligence_chat.dart';
import '../../navigation/presentation/providers/user_menu_provider.dart';

const intelligenceEnabled = bool.fromEnvironment('BARLYTICS_INTELLIGENCE', defaultValue: true);

/// Number of actual destinations before adding the final More item.
int balancedVisibleCount(int available,double width){
  final cap=width>=600?6:4;
  final total=available+1;
  final limited=total<cap?total:cap;
  return limited<=2?available:(limited.isEven?limited:limited-1)-1;
}

/// Preserves every original destination and its index. Center button is not a route.
class IntelligenceBottomNavigation extends ConsumerWidget {
  const IntelligenceBottomNavigation({super.key,required this.items,required this.onTap,
    required this.currentIndex,this.type,this.backgroundColor,this.elevation,
    this.selectedItemColor,this.unselectedItemColor,this.selectedFontSize=14,
    this.unselectedFontSize=12,this.iconSize=24,this.selectedLabelStyle,
    this.unselectedLabelStyle,this.showSelectedLabels=true,this.showUnselectedLabels=true});
  final List<BottomNavigationBarItem> items;
  final ValueChanged<int>? onTap;
  final int currentIndex;
  final BottomNavigationBarType? type;
  final Color? backgroundColor,selectedItemColor,unselectedItemColor;
  final double? elevation;
  final double selectedFontSize,unselectedFontSize,iconSize;
  final TextStyle? selectedLabelStyle,unselectedLabelStyle;
  final bool showSelectedLabels,showUnselectedLabels;

  @override
  Widget build(BuildContext context,WidgetRef ref){
    final auth=ref.watch(authControllerProvider);
    final menuAllowed=ref.watch(userMenuProvider).valueOrNull?.any((item)=>item.keyName=='intelligence')??false;
    if(!intelligenceEnabled||!auth.authenticated||!auth.subscriptionActive||!menuAllowed){
      return BottomNavigationBar(items:items,onTap:onTap,currentIndex:currentIndex,type:type,
        backgroundColor:backgroundColor,elevation:elevation,selectedItemColor:selectedItemColor,
        unselectedItemColor:unselectedItemColor,selectedFontSize:selectedFontSize,
        unselectedFontSize:unselectedFontSize,iconSize:iconSize,selectedLabelStyle:selectedLabelStyle,
        unselectedLabelStyle:unselectedLabelStyle,showSelectedLabels:showSelectedLabels,
        showUnselectedLabels:showUnselectedLabels);
    }
    final palette=ref.watch(selectedAppPaletteProvider);
    final branch=ref.watch(branchScopeProvider).activeBranch;
    final midpoint=(items.length+1)~/2;
    Widget half(int from,int to)=>Expanded(child:IntelligenceNavigationHalf(
      children:[for(var i=from;i<to;i++) _destination(i,palette)]));
    return Material(color:backgroundColor??Colors.transparent,child:Padding(
      padding:const EdgeInsets.symmetric(vertical:5),
      child:Row(children:[
        half(0,midpoint),
        SizedBox(width:72,child:Column(mainAxisSize:MainAxisSize.min,children:[
          Tooltip(message:'Abrir asistente',child:Material(
            color:palette.primary,shape:const CircleBorder(),elevation:3,child:InkWell(
              key:const Key('intelligence-center-button'),customBorder:const CircleBorder(),
              onTap:branch==null?null:()=>showIntelligenceChat(context),
              child:SizedBox(width:52,height:52,child:Icon(Icons.auto_awesome_rounded,color:palette.onPrimary,size:27))))),
          Text('Asistente',maxLines:1,style:TextStyle(color:palette.textPrimary,fontSize:10,fontWeight:FontWeight.w700)),
        ])),
        half(midpoint,items.length),
      ]),
    ));
  }
  Widget _destination(int i,AppPalette palette){
    final item=items[i],selected=i==currentIndex;
    final color=selected?(selectedItemColor??palette.secondary):(unselectedItemColor??palette.textSecondary);
    return Semantics(button:true,selected:selected,label:item.label,child:InkWell(
      onTap:()=>onTap?.call(i),child:Padding(padding:const EdgeInsets.symmetric(vertical:4,horizontal:2),
        child:Column(mainAxisSize:MainAxisSize.min,children:[
          IconTheme(data:IconThemeData(color:color,size:iconSize),child:selected?item.activeIcon:item.icon),
          if(selected?showSelectedLabels:showUnselectedLabels)
            Text(item.label??'',maxLines:1,overflow:TextOverflow.ellipsis,
              style:(selected?selectedLabelStyle:unselectedLabelStyle)?.copyWith(color:color,fontSize:selected?selectedFontSize:unselectedFontSize)
                ??TextStyle(color:color,fontSize:selected?selectedFontSize:unselectedFontSize)),
        ]))));
  }
}

/// Fill the whole half of the bar on wide screens; keep usable hit targets
/// and horizontal scrolling only when compact screens actually need it.
class IntelligenceNavigationHalf extends StatelessWidget {
  const IntelligenceNavigationHalf({super.key,required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder:(context,c){
    if(children.isEmpty)return const SizedBox.shrink();
    final width=c.maxWidth/children.length;
    if(width>=58){
      return Row(children:[for(final child in children) Expanded(child:child)]);
    }
    return SingleChildScrollView(
      scrollDirection:Axis.horizontal,
      child:Row(mainAxisSize:MainAxisSize.min,children:[
        for(final child in children) SizedBox(width:58,child:child),
      ]),
    );
  });
}
