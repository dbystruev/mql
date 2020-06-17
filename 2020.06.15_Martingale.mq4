/ / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 / / |                                                                                 2 0 2 0 . 0 6 . 1 5 _ M a r t i n g a l e . m q 4   |  
 / / |                                   C o p y r i g h t   2 0 2 0 ,   D e n i s   B y s t r u e v ,   d b y s t r u e v @ m e . c o m   |  
 / / |                                                                           h t t p s : / / g i t h u b . c o m / d b y s t r u e v   |  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
  
 # p r o p e r t y   c o p y r i g h t   " C o p y r i g h t   2 0 2 0 ,   D e n i s   B y s t r u e v ,   d b y s t r u e v @ m e . c o m "  
 # p r o p e r t y   l i n k             " h t t p s : / / g i t h u b . c o m / d b y s t r u e v "  
 # p r o p e r t y   v e r s i o n       " 1 . 0 3 "  
 # p r o p e r t y   s t r i c t  
  
 # i m p o r t   " s t d l i b . m q h "  
 s t r i n g   E r r o r D e s c r i p t i o n ( i n t   e r r o r _ c o d e ) ;  
 # i m p o r t  
  
 / / - - -   i n p u t   p a r a m e t e r s  
 i n p u t   d o u b l e   i n p u t _ l o t   =   0 . 0 1 ;             / /   i n i t i a l   l o t  
 i n p u t   d o u b l e   l o t _ a d d   =   0 . 0 1 ;                 / /   l o t   a d d i t i o n  
 i n p u t   d o u b l e   l o t _ f a c t o r   =   1 ;                 / /   l o t   m u l t i p l i c a t o r  
 i n p u t   d o u b l e   i n p u t _ b a l a n c e   =   0 ;           / /   m a x i m u m   a c c o u n t   b a l a n c e  
 i n p u t   d o u b l e   s p r e a d _ f a c t o r   =   2 ;           / /   s p r e a d   f a c t o r  
 i n p u t   d o u b l e   i n p u t _ s p r e a d   =   1 0 ;           / /   s t a r t i n g   s p r e a d  
 i n p u t   d o u b l e   t r a i l i n g _ l e v e l   =   0 . 5 ;     / /   t r a i l i n g   l e v e l  
 i n p u t   b o o l   i n p u t _ u s e _ s t o p   =   t r u e ;       / /   u s e   s t o p   ( t r u e )   o r   l i m i t   ( f a l s e )   o r d e r s  
  
 / / - - -   i n d e p e n d e n t   g l o b a l   v a r i a b l e s  
 s t r i n g   e r r o r   =   " " ;  
 b o o l   u s e _ s t o p _ o r d e r s   =   i n p u t _ u s e _ s t o p ;  
  
 / / - - -   d e p e n d e n t   g l o b a l   v a r i a b l e s  
 d o u b l e   c u r r e n t _ l o t ;  
 i n t   c u r r e n t _ s p r e a d ;  
 d o u b l e   l a s t _ b a l a n c e ;  
 d o u b l e   l o t _ s t a r t ;  
 d o u b l e   m a x _ b a l a n c e ;  
 i n t   o r d e r _ t y p e 1 ;  
 i n t   o r d e r _ t y p e 2 ;  
 d o u b l e   p r e v i o u s _ l o t ;  
 i n t   p r e v i o u s _ s p r e a d ;  
 i n t   s p r e a d _ s t a r t ;  
  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 / / |   D e l e t e   t h e   o r d e r s   o f   g i v e n   t y p e s .   R e t u r n s   t r u e   i f   d e l e t e d .               |  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 b o o l   d e l e t e _ o r d e r s ( i n t   t y p e 1 ,   i n t   t y p e 2 )  
     {  
       b o o l   r e s u l t   =   t r u e ;  
       f o r ( i n t   i   =   0 ;   i   <   O r d e r s T o t a l ( ) ;   i + + )  
           {  
             i f ( O r d e r S e l e c t ( i ,   S E L E C T _ B Y _ P O S ) )  
                 {  
                   i f ( ( O r d e r T y p e ( )   = =   t y p e 1 )   | |   ( O r d e r T y p e ( )   = =   t y p e 2 ) )  
                       {  
                         r e s u l t   =   r e s u l t   & &   O r d e r D e l e t e ( O r d e r T i c k e t ( ) ) ;  
                       }  
                 }  
           }  
       i f ( ! r e s u l t )  
           {  
             e r r o r   =   " E R R O R   i n   d e l e t e _ o r d e r s ( "   +   s t r i n g ( t y p e 1 )   +   " ,   "   +   s t r i n g ( t y p e 2 )   +   " ) :   "   +   E r r o r D e s c r i p t i o n ( G e t L a s t E r r o r ( ) ) ;  
           }  
       r e t u r n   r e s u l t ;  
     }  
  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 / / |   E x p e r t   i n i t i a l i z a t i o n   f u n c t i o n                                                                       |  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 i n t   O n I n i t ( )  
     {  
 / / - - -  
       u p d a t e _ a l l ( ) ;  
 / / - - -  
       r e t u r n ( I N I T _ S U C C E E D E D ) ;  
     }  
  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 / / |   E x p e r t   d e i n i t i a l i z a t i o n   f u n c t i o n                                                                   |  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 v o i d   O n D e i n i t ( c o n s t   i n t   r e a s o n )  
     {  
 / / - - -  
  
     }  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 / / |   E x p e r t   t i c k   f u n c t i o n                                                                                           |  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 v o i d   O n T i c k ( )  
     {  
 / / - - -  
       u p d a t e _ b a l a n c e ( ) ;  
       s t r i n g   s p a c e   =   " \ n                                 " ;  
       C o m m e n t (  
             s p a c e ,   " L a s t   b a l a n c e   =   " ,   l a s t _ b a l a n c e ,  
             s p a c e ,   " M a x   b a l a n c e   =   " ,   m a x _ b a l a n c e ,  
             s p a c e ,   " C u r r e n t   l o t   =   " ,   c u r r e n t _ l o t ,  
             s p a c e ,   " C u r r e n t   s p r e a d   =   " ,   c u r r e n t _ s p r e a d ,  
             s p a c e ,   e r r o r  
       ) ;  
  
 / /   M a i n   l o o p  
       s w i t c h ( t o t a l _ o r d e r s ( o r d e r _ t y p e 1 ,   o r d e r _ t y p e 2 ) )  
           {  
             c a s e   0 :  
                   s w i t c h ( t o t a l _ o r d e r s ( O P _ B U Y ,   O P _ S E L L ) )  
                       {  
                         c a s e   0 :  
                               s e n d _ o r d e r s ( o r d e r _ t y p e 1 ,   o r d e r _ t y p e 2 ) ;  
                               b r e a k ;  
                         d e f a u l t :  
                               s e t _ l o t _ s p r e a d ( O P _ B U Y ,   O P _ S E L L ) ;  
                               i f ( m a x _ b a l a n c e   <   A c c o u n t E q u i t y ( ) )  
                                   {  
                                     t r a i l _ o r d e r s ( O P _ B U Y ,   O P _ S E L L ) ;  
                                   }  
                               b r e a k ;  
                       }  
                   b r e a k ;  
             c a s e   1 :  
                   d e l e t e _ o r d e r s ( o r d e r _ t y p e 1 ,   o r d e r _ t y p e 2 ) ;  
                   b r e a k ;  
             d e f a u l t :  
                   s e t _ l o t _ s p r e a d ( o r d e r _ t y p e 1 ,   o r d e r _ t y p e 2 ) ;  
                   b r e a k ;  
           }  
     }  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 / / |   S e n d   a n   o r d e r   o f   g i v e n   t y p e .   R e t u r n s   t i c k e t   n u m b e r   o r   - 1                   |  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 i n t   s e n d _ o r d e r ( i n t   t y p e )  
     {  
       d o u b l e   p r i c e ;  
       i n t   r e s u l t   =   0 ;  
       d o u b l e   s p r e a d   =   u s e _ s t o p _ o r d e r s   ?   s p r e a d _ s t a r t   :   c u r r e n t _ s p r e a d ;  
       i n t   s i g n   =   u s e _ s t o p _ o r d e r s   ?   1   :   - 1 ;  
       s w i t c h ( t y p e )  
           {  
             c a s e   O P _ B U Y S T O P :  
             c a s e   O P _ S E L L L I M I T :  
                   p r i c e         =   ( A s k   +   B i d )   /   2   +   P o i n t   *   s p r e a d ;  
                   p r i c e         =   P o i n t   *   M a t h R o u n d ( p r i c e   /   P o i n t ) ;  
                   p r i c e         =   M a t h M a x ( p r i c e ,   A s k   +   P o i n t   *   s p r e a d ) ;  
                   r e s u l t       =   O r d e r S e n d ( _ S y m b o l ,   t y p e ,   c u r r e n t _ l o t ,   p r i c e ,   0 ,   p r i c e   -   s i g n   *   P o i n t   *   c u r r e n t _ s p r e a d ,   p r i c e   +   s i g n   *   P o i n t   *   c u r r e n t _ s p r e a d ) ;  
                   b r e a k ;  
             c a s e   O P _ B U Y L I M I T :  
             c a s e   O P _ S E L L S T O P :  
                   p r i c e         =   ( A s k   +   B i d )   /   2   -   P o i n t   *   s p r e a d ;  
                   p r i c e         =   P o i n t   *   M a t h R o u n d ( p r i c e   /   P o i n t ) ;  
                   p r i c e         =   M a t h M i n ( p r i c e ,   B i d   -   P o i n t   *   s p r e a d ) ;  
                   r e s u l t       =   O r d e r S e n d ( _ S y m b o l ,   t y p e ,   c u r r e n t _ l o t ,   p r i c e ,   0 ,   p r i c e   +   s i g n   *   P o i n t   *   c u r r e n t _ s p r e a d ,   p r i c e   -   s i g n   *   P o i n t   *   c u r r e n t _ s p r e a d ) ;  
                   b r e a k ;  
           }  
       i f ( r e s u l t   <   0 )  
           {  
             e r r o r   =   " E R R O R   i n   s e n d _ o r d e r ( "   +   s t r i n g ( t y p e )   +   " ) :   "   +   E r r o r D e s c r i p t i o n ( G e t L a s t E r r o r ( ) ) ;  
           }  
       r e t u r n   r e s u l t ;  
     }  
  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 / / |   S e n d   o r d e r s   o f   g i v e n   t y p e s                                                                               |  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 v o i d   s e n d _ o r d e r s ( i n t   t y p e 1 ,   i n t   t y p e 2 )  
     {  
       i f ( A c c o u n t B a l a n c e ( )   <   m a x _ b a l a n c e )  
           {  
             i f ( A c c o u n t B a l a n c e ( )   <   l a s t _ b a l a n c e )  
                 {  
                   c u r r e n t _ l o t   =   l o t _ f a c t o r   *   c u r r e n t _ l o t   +   l o t _ a d d ;  
                   c u r r e n t _ s p r e a d   =   ( i n t )   s p r e a d _ f a c t o r   *   c u r r e n t _ s p r e a d ;  
                 }  
             e l s e  
                   i f ( l a s t _ b a l a n c e   <   A c c o u n t B a l a n c e ( ) )  
                       {  
                         c u r r e n t _ l o t   =   M a t h M a x ( l o t _ s t a r t ,   ( c u r r e n t _ l o t   -   l o t _ a d d )   /   l o t _ f a c t o r ) ;  
                         c u r r e n t _ s p r e a d   =   ( i n t )   M a t h M a x ( s p r e a d _ s t a r t ,   c u r r e n t _ s p r e a d   /   s p r e a d _ f a c t o r ) ;  
                       }  
             l a s t _ b a l a n c e   =   A c c o u n t B a l a n c e ( ) ;  
           }  
       e l s e  
           {  
             u p d a t e _ l o t _ s p r e a d ( ) ;  
           }  
       i f ( 0   <   s e n d _ o r d e r ( t y p e 1 )   & &   0   <   s e n d _ o r d e r ( t y p e 2 ) )  
           {  
             u p d a t e _ e r r o r _ l a s t _ p r e v i o u s ( ) ;  
           }  
     }  
  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 / / |   S e t   c u r r e n t   l o t   a n d   s p r e a d   f r o m   e x i s t i n g   b u y / s e l l   o r d e r                     |  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 v o i d   s e t _ l o t _ s p r e a d ( i n t   t y p e 1 ,   i n t   t y p e 2 )  
     {  
       f o r ( i n t   i   =   0 ;   i   <   O r d e r s T o t a l ( ) ;   i + + )  
           {  
             i f ( O r d e r S e l e c t ( i ,   S E L E C T _ B Y _ P O S ) )  
                 {  
                   i f ( ( O r d e r T y p e ( )   = =   t y p e 1 )   | |   ( O r d e r T y p e ( )   = =   t y p e 2 ) )  
                       {  
                         c u r r e n t _ l o t   =   O r d e r L o t s ( ) ;  
                         c u r r e n t _ s p r e a d   =   ( i n t )   M a t h A b s ( ( O r d e r O p e n P r i c e ( )   -   O r d e r S t o p L o s s ( ) )   /   P o i n t ) ;  
                       }  
                 }  
           }  
     }  
  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 / / |   N u m b e r   o f   o r d e r s   o f   g i v e n   t y p e s                                                                     |  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 i n t   t o t a l _ o r d e r s ( i n t   t y p e 1 ,   i n t   t y p e 2 )  
     {  
       i n t   t o t a l _ o r d e r s   =   0 ;  
       f o r ( i n t   i   =   0 ;   i   <   O r d e r s T o t a l ( ) ;   i + + )  
           {  
             i f ( O r d e r S e l e c t ( i ,   S E L E C T _ B Y _ P O S ) )  
                 {  
                   i f ( ( O r d e r T y p e ( )   = =   t y p e 1 )   | |   ( O r d e r T y p e ( )   = =   t y p e 2 ) )  
                       {  
                         t o t a l _ o r d e r s + + ;  
                       }  
                 }  
           }  
       r e t u r n   ( t o t a l _ o r d e r s ) ;  
     }  
  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 / / |   T r a i l   b u y   o r   s e l l   o r d e r .   R e t u r n s   t r u e   i f   t r a i l   s u c c e s s f u l l               |  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 b o o l   t r a i l _ o r d e r ( i n t   t i c k e t )  
     {  
       b o o l   r e s u l t   =   f a l s e ;  
       d o u b l e   s t o p l o s s ;  
       i f ( O r d e r S e l e c t ( t i c k e t ,   S E L E C T _ B Y _ T I C K E T ) )  
           {  
             b o o l   p r o f i t a b l e   =   m a x _ b a l a n c e   <   A c c o u n t B a l a n c e ( )   +   t r a i l i n g _ l e v e l   *   ( A c c o u n t E q u i t y ( )   -   A c c o u n t B a l a n c e ( ) ) ;  
             s w i t c h ( O r d e r T y p e ( ) )  
                 {  
                   c a s e   O P _ B U Y :  
                         s t o p l o s s   =   O r d e r O p e n P r i c e ( )   +   t r a i l i n g _ l e v e l   *   ( B i d   -   O r d e r O p e n P r i c e ( ) ) ;  
                         s t o p l o s s   =   P o i n t   *   M a t h R o u n d ( s t o p l o s s   /   P o i n t ) ;  
                         s t o p l o s s   =   M a t h M i n ( s t o p l o s s ,   B i d   -   P o i n t   *   c u r r e n t _ s p r e a d ) ;  
                         i f ( ( O r d e r O p e n P r i c e ( )   <   s t o p l o s s )   & &   ( O r d e r S t o p L o s s ( )   <   s t o p l o s s )   & &   p r o f i t a b l e )  
                             {  
                               r e s u l t   =   O r d e r M o d i f y ( t i c k e t ,   O r d e r O p e n P r i c e ( ) ,   s t o p l o s s ,   0 . 0 ,   0 ) ;  
                             }  
                         b r e a k ;  
                   c a s e   O P _ S E L L :  
                         s t o p l o s s   =   O r d e r O p e n P r i c e ( )   -   t r a i l i n g _ l e v e l   *   ( O r d e r O p e n P r i c e ( )   -   A s k ) ;  
                         s t o p l o s s   =   P o i n t   *   M a t h R o u n d ( s t o p l o s s   /   P o i n t ) ;  
                         s t o p l o s s   =   M a t h M a x ( s t o p l o s s ,   A s k   +   P o i n t   *   c u r r e n t _ s p r e a d ) ;  
                         i f ( ( s t o p l o s s   <   O r d e r O p e n P r i c e ( ) )   & &   ( s t o p l o s s   <   O r d e r S t o p L o s s ( ) )   & &   p r o f i t a b l e )  
                             {  
                               r e s u l t   =   O r d e r M o d i f y ( t i c k e t ,   O r d e r O p e n P r i c e ( ) ,   s t o p l o s s ,   0 . 0 ,   0 ) ;  
                             }  
                         b r e a k ;  
                 }  
           }  
       i f ( ! r e s u l t )  
           {  
             i n t   l a s t _ e r r o r   =   G e t L a s t E r r o r ( ) ;  
             i f ( l a s t _ e r r o r   ! =   E R R _ N O _ E R R O R )  
                 {  
                   e r r o r   =   " E R R O R   i n   t r a i l _ o r d e r ( "   +   s t r i n g ( t i c k e t )   +   " ) :   "   +   E r r o r D e s c r i p t i o n ( l a s t _ e r r o r ) ;  
                 }  
           }  
       r e t u r n   r e s u l t ;  
     }  
  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 / / |                                                                                                                                     |  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 v o i d   t r a i l _ o r d e r s ( i n t   t y p e 1 ,   i n t   t y p e 2 )  
     {  
       f o r ( i n t   i   =   0 ;   i   <   O r d e r s T o t a l ( ) ;   i + + )  
           {  
             i f ( O r d e r S e l e c t ( i ,   S E L E C T _ B Y _ P O S ) )  
                 {  
                   i f ( ( O r d e r T y p e ( )   = =   t y p e 1 )   | |   ( O r d e r T y p e ( )   = =   t y p e 2 ) )  
                       {  
                         t r a i l _ o r d e r ( O r d e r T i c k e t ( ) ) ;  
                       }  
                 }  
           }  
     }  
  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 / / |   U p d a t e   a l l   v a r i a b l e s                                                                                           |  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 v o i d   u p d a t e _ a l l ( )  
     {  
       u p d a t e _ b a l a n c e ( ) ;  
       u p d a t e _ l o t _ s p r e a d ( ) ;  
       u p d a t e _ e r r o r _ l a s t _ p r e v i o u s ( ) ;  
       u p d a t e _ o r d e r _ t y p e ( ) ;  
     }  
  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 / / |   U p d a t e   m a x   b a l a n c e                                                                                               |  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 v o i d   u p d a t e _ b a l a n c e ( )  
     {  
       m a x _ b a l a n c e   =   M a t h M a x ( A c c o u n t B a l a n c e ( ) ,   i n p u t _ b a l a n c e ) ;  
     }  
  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 / / |   U p d a t e   b a l a n c e ,   l o t ,   a n d   s p r e a d   v a r i a b l e s                                                 |  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 v o i d   u p d a t e _ l o t _ s p r e a d ( )  
     {  
       l o t _ s t a r t   =   M a t h M a x ( M a r k e t I n f o ( S y m b o l ( ) ,   M O D E _ M I N L O T ) ,   i n p u t _ l o t ) ;  
       c u r r e n t _ l o t   =   l o t _ s t a r t ;  
  
       s p r e a d _ s t a r t   =   ( i n t )   M a t h M a x ( 3   *   M a r k e t I n f o ( _ S y m b o l ,   M O D E _ S P R E A D ) ,   i n p u t _ s p r e a d ) ;  
       c u r r e n t _ s p r e a d   =   s p r e a d _ s t a r t ;  
     }  
  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 / / |   U p d a t e   e r r o r ,   l a s t ,   a n d   p r e v i o u s   v a r i a b l e s                                               |  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 v o i d   u p d a t e _ e r r o r _ l a s t _ p r e v i o u s ( )  
     {  
       e r r o r   =   " " ;  
       l a s t _ b a l a n c e   =   A c c o u n t B a l a n c e ( ) ;  
       p r e v i o u s _ l o t   =   c u r r e n t _ l o t ;  
       p r e v i o u s _ s p r e a d   =   c u r r e n t _ s p r e a d ;  
     }  
  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 / / |   U p d a t e   o r d e r   t y p e   v a r i a b l e s                                                                             |  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 v o i d   u p d a t e _ o r d e r _ t y p e ( )  
     {  
       o r d e r _ t y p e 1   =   u s e _ s t o p _ o r d e r s   ?   O P _ B U Y S T O P   :   O P _ S E L L L I M I T ;  
       o r d e r _ t y p e 2   =   u s e _ s t o p _ o r d e r s   ?   O P _ S E L L S T O P   :   O P _ B U Y L I M I T ;  
     }  
 / / + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +  
 