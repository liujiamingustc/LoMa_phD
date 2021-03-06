!***********************************************************************!
!                                                                       !
!     Compute and write fields in phys space                            !
!                                                                       !
!                                                                       !
!     AAF     24/05/17  From TOFIS transofrmed to compute PQR invar.    !
!                                                                       !
!***********************************************************************!
 
      program main
      
      implicit none 
      include "ctes3D"
      
      ! -------------------- Commons ----------------------------------!

      integer iinp,iswap
      character*80 filinp,filout,filswap
      character*4  extensiones
      common /ficheros/ iinp,iswap,filinp,filout,filswap,extensiones(8)
      save /ficheros/
      
      real*4  Re,alp,bet,a0
      real*8  y,fmap
      common /fis/ Re,alp,bet,a0,y(my),fmap(my)
      save   /fis/

      integer nvecy,plx
      real*4 Deltat,CFL,time,dtr
      common /tem/ Deltat,CFL,time,dtr,nvecy,plx
      save /tem/

      integer      icx
      real*4       alp2,bet2
      complex*8    xalp, xbet
      common /wave/ xalp(0:mx1),xbet(0:mz1),alp2(0:mx1),bet2(0:mz1),
     &              icx(0:mz1)
      save  /wave/

      ! ----------------------- constants -----------------------------!
      
      integer nbuffou,nbuffis,i,j,k,nlines,nbuffbig,jj,buc,fj
!      integer nbuffou,nbuffis,i,j,k,isn,nlines,nbuffbig,jj,buc,fj
      real*8  u00(my),v00(my),w00(my),du00(my),dw00(my),dv00(my)
!aaf added fj

      integer time1,time2,time3,time4,time5,timepk1,timepk2,irate
      real*8  timetot,timel1,timel2a,timel2b,timel3,timel2

      integer tb1,tb2,tb3,tb4,tb5,ind
      real*4 ttot1,ttot2,ttot3,dum
      
      real*4, allocatable:: vor(:,:,:),phi(:,:,:),      
     .        u(:),v(:),w(:),du(:,:),dudy(:),dvdy(:),dwdy(:),
     .        wk1(:),wk2(:),wk3(:),wk4(:),wk5(:),wk6(:),wk7(:),
     .        wk(:,:),pr(:),ps(:),wkT(:),ufou(:),vfou(:),wfou(:),
     .        psi(:,:,:),scal(:,:,:),dscal(:),scal2(:)
     
      character*80 fnamesta,fnameima

      ! ------------------------ Program ------------------------------!
c      /*   initializes everything    */  
      !ind=1
c--------------- initializes commons and things 
      write(*,*) 'Initalizing ...'      
      call initcr(u00,v00,w00)  

      nbuffou = 2*mz*my*plx
      !allocating memmory... 
      allocate(vor(2*my,0:mz1,plx))
      allocate(phi(2*my,0:mz1,plx))
      allocate(psi(2*my,0:mz1,plx))
      allocate(scal(2*my,0:mz1,plx))
      
      allocate(u(nbuffou))
      allocate(v(nbuffou))
      allocate(w(nbuffou))
      allocate(dudy(nbuffou))
      allocate(dvdy(nbuffou))
      allocate(dwdy(nbuffou))
      allocate(dscal(nbuffou))
      allocate(scal2(nbuffou))

      allocate(wk(0:mx1,0:mz1))

      !calculate wk matrix with 1/RK's
      do j=0,mz1
         do i=0,mx1
            wk(i,j)=1.0/(alp2(i) + bet2(j))
         enddo
      enddo
      wk(0,0)=0.


      
      write(*,*)'Allocated memory:',
     %           4*((nbuffou*10+7*(my*mz))/1048576),'MB'
     
      call deryr (u00,du00)
      call deryr (v00,dv00)
      call deryr (w00,dw00)
      
      call system_clock(time1,irate)
      ttot1 =0d0
      ttot2 = 0d0
 
      !----------- begin operations in yz planes ---------------------!
      
      timel1 = 0d0 
      do i=1,mx1+1,plx  !,mx1+1,plx ! !
         write(*,*) 'Plane: ',i,'of ', mx1+1
         call system_clock(tb1,irate)
             
        ! ---       reads ix=constant plane
         do jj=1,plx
            read(iinp)((vor(j,k,jj),phi(j,k,jj),psi(j,k,jj),
     .          scal(j,k,jj),j=1,2*my),k=0,mz1)
         enddo 
         
         call system_clock(tb2,irate)

         ttot2 = ttot2 + real(tb2-tb1)/real(irate)
       
         !Making some operations on y for quantities needed
         !Inputs: vor, phi, psi, scal
         call uvwyzx(vor,phi,psi,scal,u,v,w,dudy,dvdy,dwdy,dscal,
     .               scal2,wk,plx,i)
         !Outputs:
         !      u => rhou
         !      v => rhov
         !      w => rhow
         !      dudy => drhou/dy
         !      dvdy => drhov/dy
         !      dwdy => drhow/dy
         !      dscal => dT/dy
         !      scal2 => T

         ! Warning. fouryz will destroy the structure of u!!!!

         call system_clock(tb1,irate)
         ttot1 = ttot1 + real(tb1-tb2)/real(irate)

         write(*,*) 'parcial calculo',abs(real(tb2-tb1)/real(irate))
         
         call swap(u   ,vor,vor,i,plx,1)  ! rhou
         call swap(v   ,vor,vor,i,plx,2)  ! rhov
         call swap(w   ,vor,vor,i,plx,3)  ! rhow
         call swap(dudy,vor,vor,i,plx,4)  ! drhou/dy
         call swap(dwdy,vor,vor,i,plx,5)  ! drhow/dy
         call swap(scal2,vor,vor,i,plx,6)  ! T
         call swap(dscal,vor,vor,i,plx,7)  ! dT/dy
         call swap(dvdy,vor,vor,i,plx,8)  ! drhov/dy

         call system_clock(tb2,irate)
         ttot2 = ttot2 + real(tb2-tb1)/real(irate)
         write(*,*) 'Parcial swap',real(tb2-tb1)/real(irate)
      enddo

      close (iinp)
      call system_clock(time2,irate)
      timel1 = dble(time2 - time1)/dble(irate)

      write(*,*) '-----------------------------------------------'

      write(*,*) 'time for yz ops:',real(time2 - time1)/real(irate)

      write(*,*) '-----------------------------------------------'

      write(*,*) '-----------------------------------------------'

      write(*,*) 'Calculo de u y du ',ttot1
      write(*,*) 'swap',ttot2

      write(*,*) '-----------------------------------------------'

      !  Lines - lines - lines 
      
      ! Deallocate memory
      
      deallocate(vor,phi,psi,scal,u,v,w,dudy,dvdy,dwdy,dscal,scal2)
       !,wkb)
      ! Planos xz ! ! Planos xz ! ! Planos xz !
      
      nbuffou = mx*mz*nvecy
      nbuffis = (mbx+2)*mbz
      
      write(*,*)'Allocated memory:',
     %           4*((10*nbuffou+11*nbuffis)/1048576),'MB'
      
      ! -------------------- allocates buffers -------------------------!

      allocate(u(nbuffou),v(nbuffou),w(nbuffou),pr(nbuffou))
      allocate(dudy(nbuffou),dvdy(nbuffou),dwdy(nbuffou),ps(nbuffou))
      allocate(wk1(nbuffis),wk2(nbuffis),wk3(nbuffis),wk4(nbuffis))
      allocate(wk5(nbuffis),wk6(nbuffis),wk7(nbuffis),wkT(nbuffis))
      allocate(dscal(nbuffou),scal2(nbuffou))
      allocate(ufou(nbuffis),vfou(nbuffis),wfou(nbuffis))

      timel2 = 0d0


      do j=1,my
         if (mod(j,10)==0) write(*,*) ' Computing plane', j,'of',my

         call system_clock(timepk1,irate)
         write(*,*) "j=",j

         call getswapyz2xz(u    ,pr,pr,j,1) !rhou
         call getswapyz2xz(v    ,pr,pr,j,2) !rhov
         call getswapyz2xz(w    ,pr,pr,j,3) !rhow
         call getswapyz2xz(dudy ,pr,pr,j,4) !drhoudy
         call getswapyz2xz(dwdy ,pr,pr,j,5) !drhowdy
         call getswapyz2xz(scal2 ,pr,pr,j,6) !scal
         call getswapyz2xz(dscal,pr,pr,j,7) !dT/dy
         call getswapyz2xz(dvdy,pr,pr,j,8) !drhovdy

c ---    reads a ix=constant plane
      ! Uncomment the following routine if you want velocities or 
      ! Vorticities in physics space
      ! 
      ! fvor(1,1,1) -> wx,wy,wz
      fj=0
      !if (ind.le.nspec) then
      write(*,*) "CALLING SCRPHYS"
!         write(*,*)'chequeando',ind,j,jspecy(ind)
      if (j.ge.ispec1.and.j.le.ispec2) then
          fj=1 !write plane xz
       !    ind=ind+1
      endif
      !endif
      !All calculations for u,v,w,vorx,vory and vorz are within
      ! escrphys subroutine
      call escrphys(u,v,w,dudy,dwdy,dvdy,dscal,scal2,wk,
     %              wk1,wk1,wk2,wk2,wk3,wk3,wk4,wk4,
     %              wk5,wk5,wk6,wk6,wk7,wk7,wkT,wkT,
     %              ufou,ufou,vfou,vfou,wfou,wfou,
     %              u00,v00,w00,du00,dv00,dw00,j,fj)

         call system_clock(timepk2,irate)

         timel2 = timel2 + abs(dble(timepk1-timepk2)/dble(irate))

      enddo

      deallocate(u,v,w,dudy,dwdy,dvdy,pr,ps,wk1,wk2,wk3,wk4,wk5,wk6,
     .           wk7,wkT,wk,dscal,ufou,vfou,wfou)

      call system_clock(time3,irate)
      
      write(*,*) '-----------------------------------------------'
      write(*,*) 'time for x ops:',timel2
      write(*,*) '-----------------------------------------------'
      write(*,*) '-----------------------------------------------'
      write(*,*) '            dealocateado                       '
      write(*,*) '-----------------------------------------------'

       write(*,*) "we are now just about to deallocate"
      

      write(*,*) '-----------------------------------------------'
      write(*,*) 'Total',timel1+timel2
      write(*,*) '-----------------------------------------------' 
      write(*,*) 
      write(*,*) '-----------------------------------------------' 
      write(*,*) '-----------------------------------------------' 
!********

      end

!***********************************************************************!
!     Subroutine initcr                                                 !
!                                                                       !
!     Initializes commons                                               !
!     Adapted, SHC 20-12-05                                             !
!     Adapted, AAF 10-07-14
!                                                                       !
!***********************************************************************!

      subroutine initcr(u00,v00,w00)
      
      implicit none 
      include "ctes3D"

!     ------------------------- COmmons --------------------------------!

      real*4  Re,alp,bet,a0
      real*8  y,fmap
      common /fis/ Re,alp,bet,a0,y(my),fmap(my)
      save   /fis/

      integer nvecy,plx
      real*4 Deltat,CFL,time,dtr
      common /tem/ Deltat,CFL,time,dtr,nvecy,plx
      save /tem/
      
      integer iinp,iswap
      character*80 filinp,filout,filswap
      character*4  extensiones
      common /ficheros/ iinp,iswap,filinp,filout,filswap,extensiones(9)
      save /ficheros/
     
!      real*8 d21,d22,dt21
!      common /secder/ d21(my,5),d22(my,5),dt21(5,my)
!      save   /secder/
      real*8 prem3,dt21,dt22
      common /d2y/ prem3(5,my),dt21(5,my),dt22(5,my)
      save   /d2y/

!      real*8 prem3,dt22
!      common /d2y/ prem3(my,5),dt22(5,my)
!      save   /d2y/

      real*8 prem1,dt12
      common /cfdiff/ prem1(my,7),dt12(7,my)
      save   /cfdiff/
      
      integer icx
      real*4 alp2,bet2
      complex*8    xalp, xbet
      common /wave/ xalp(0:mx1),xbet(0:mz1),alp2(0:mx1),bet2(0:mz1),
     &              icx(0:mz1)
      save  /wave/
      
      real*8 um,vm,wm,up,vp,wp,w1m,w2m,w3m,w1p,w2p,w3p,prr,prs,pso,
     &       ptt,Wx0a,Wz0a,uvr,uwr,vwr
      integer nacum
      common /stat1/ um(my), vm(my), wm(my), up(my), vp(my), wp(my),
     &       w1m(my),w2m(my),w3m(my),w1p(my),w2p(my),w3p(my),uvr(my),
     &  uwr(my),vwr(my),prr(my),prs(my),pso(my),ptt(my),Wx0a,Wz0a,nacum
      save /stat1/


      real*8 prod,disp,turb,visd,pstr,pdif
      common /tensors/ prod(my,6),disp(my,6),turb(my,6),
     &                 visd(my,6),pstr(my,6),pdif(my,6)
      save   /tensors/      

      real*8 pret,vi2d,turr
      common /nten/ pret(my,6),vi2d(my,6),turr(my,6)
      save   /nten/

      

!     ----------------- Workspaces -------------------------------------!

      real*8, allocatable::d11(:,:),d12(:,:),d21(:,:),d22(:,:)
      integer idat(20),mybu,mzbu,i,j,iproc,jj,istart,ifor,idif,k,
     &        mxe,mye,mze
      
!      real*4 dat(20),zero,Delt,u00(*),w00(*),wk2(2*my)
      real*4 dat(20),zero,Delt,wk2(3*my)
      real*8 u00(*),v00(*),w00(*)
!      real*4 u00(*),w00(*)
      character*80 text
      
!     -----------------PROGRAMA ----------------------------------------!
      
      zero = 0e0
      
!     ---------------- reads in data  ----------------------------------!
      
      !open hre.dat if first file
      open(19,file='hre.dat',status='old')

64    read(19,'(a)') text
      if(text(1:2).eq.'CC') goto 64
      read(text,*) (idat(i),i=1,2)

      nvecy = idat(1)
      plx   = idat(2)
      

65    read(19,'(a)') text
      if(text(1:2).eq.'CC') goto 65
      read(text,'(a80)') filswap

166   read(19,'(a)') text
      if(text(1:2).eq.'CC') goto 166
      read(text,'(a80)') filinp

167   read(19,'(a)') text
      if(text(1:2).eq.'CC') goto 167
      read(text,'(a80)') filout

      iinp=69
      iswap=2
      close(19)
      
      extensiones(1) = 'rhou'
      extensiones(2) = 'rhov'
      extensiones(3) = 'rhow'
      extensiones(4) = 'drhu'
      extensiones(5) = 'drhw'
      extensiones(6) = 'scal'
      extensiones(7) = 'dtdy'
      !
      extensiones(8)= 'drhv'
      extensiones(9)= 'ps'
                       
      ! Read head of file
      
      write(*,*) filinp,filout
      
      open(iinp,file=filinp,status='old',form='unformatted')
      write(*,*) 'archivo abierto' 

      read(iinp) time,Re,alp,bet,a0,mxe,mye,mze,
     &             (y(j),fmap(j),j=1,my),(wk2(j),j=1,3*my)

      write(*,*) 'time of field = ',time
     
      if(mx .ne.mxe . OR .
     &   my .ne.mye . OR .
     &   mz .ne.mze       ) then
         write(*,*) 'parameters changed'
         write(*,*) 'mx=',mx,mxe
         write(*,*) 'my=',my,mye
         write(*,*) 'mz=',mz,mze
         write(*,*) 'MX/Y/Z not matching MXE/MYE/MZE,TRY AGAIN :-)'
         stop
      endif
     
      do j=1,my
         u00(j) = wk2(3*j-2)
         v00(j) = wk2(3*j-1)
         w00(j) = wk2(3*j)
      enddo
     
      write(*,*) 'inicializamos' 

c    ---------  initializes fast fourier transforms ----

      call cfti(mgalz)
      call rfti(mgalx)

c    -----------  write header for output -------------

      write(*,'(a7,f8.2,a8,f6.3,a8,f6.3)') '  Re =',Re,'channel'
      write(*,'(a7,f8.3,a8,f6.3,a8,f6.3)')
     .              'alp =',alp,'  bet =',bet
      write(*,*)

      write(*,'(a8,i5,a8,i5,a8,i5)')
     .              'mgalx =',mgalx,'mgalz =',mgalz,'my =',my
      write(*,'(a8,i5,a8,i5,a8,i5)')
     .              'mx =',mx,'mz =',mz
      write(*,*)

      write(*,'(a10,i5,a8,i5)')
     .        'y planes =',nvecy,' xplanes',plx
      write(*,*)
      write(*,'(a,a)') 'reading from:  ',filinp
      write(*,*)
      write(*,'(a,a)') '  swap in :  ',filswap
      write(*,*)
      write(*,'(a,a)') '  out in :  ',filout
!AAF----------------------------------------------------

!      allocate(d11(my,7),d12(my,7))
      allocate(d11(my,7),d12(my,7),d21(my,5),d22(my,5))

      call derivadas(d11,d12,d21,d22)          

      deallocate(d11,d12,d21,d22)
      write(*,*) 'Fin precalculo de matrices...'

c ------------  compute y coordinates, pointers and
c ------------  modes values for FOURIER      

      do k=0,nz1
         xbet(k) = cmplx(zero,bet*k)
         icx(k) = k
      enddo

      do k=nz1+1,mz1
         xbet(k) = cmplx(zero ,-bet*(mz1+1-k))
      enddo

      do k=1,nz1
         icx(mz-k) = k
      enddo
      
      do i=0,mx1
         xalp(i) = cmplx(zero ,alp*i)
      enddo

      do i=0,mx1
         alp2(i) = -xalp(i)**2
      enddo

      do j=0,mz1
         bet2(j) = -xbet(j)**2
      enddo

      do j=1,my
         um(j)  = 0d0
         vm(j)  = 0d0
         wm(j)  = 0d0
         up(j)  = 0d0
         vp(j)  = 0d0
         wp(j)  = 0d0
         w1m(j) = 0d0
         w2m(j) = 0d0
         w3m(j) = 0d0
         w1p(j) = 0d0
         w2p(j) = 0d0
         w3p(j) = 0d0
         prr(j) = 0d0
         prs(j) = 0d0
         pso(j) = 0d0
         ptt(j) = 0d0
         uvr(j) = 0d0
         uwr(j) = 0d0
         vwr(j) = 0d0
      enddo
      do k=1,6
         do j=1,my
            prod(j,k)= 0d0
            disp(j,k)= 0d0
            turb(j,k)= 0d0
            visd(j,k)= 0d0
            pstr(j,k)= 0d0
            pdif(j,k)= 0d0
            pret(j,k)= 0d0
            turr(j,k)= 0d0
         enddo
      enddo

      end
