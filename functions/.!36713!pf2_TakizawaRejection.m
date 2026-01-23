function fMask=pf2_TakizawaRejection(fNIR,strictCriteria)
     %% Measures and optionally applies takizawa rejection criteria
     %  this script will just measure the Takizawa critera for rejection
     %  	Use applyMask =true to merge with the fchMask
     %      Use strictCriteria =true to merge the strict criteria with the
     %      mask   (uses "or" instead of "and" for the takizawa criteria
     %               actual papers are somewhat ambiguous about the logic)
     
     %  Method was originally designed for use with the Hitachi Etg-4000
     %  during a ~60 second verbal fluency task while sampling at 10hz
     %      Some factors including unit conversion were adjusted in
     %      order for this to be functional for other devices, namely
     %          1)Aproximation of units in mM*mm instead of uM
     %          2)Use/Conversion for alternate sampling frequencies
     %          3)High frequency conversion calculated as percentage of
     %          windows rather than 4 specific time periods
     %          4)Instead of 1 artifact >0.15mMmm, a margin is specified
     %          (windowsize/2)
     
     %      Due to differences in between the 2008 and 2014 methodologies,
     %      band power calculations for rule 2(2008) are conducted but not used specifically
     %      in rejection. These items appeared to be unit specific and may
     %      not be good represenations on other devices. Therefore the 2014
     %      rules are used because they are unitless.
     %      Additionally the first rule for 2008 specificed the elimination
     %      of channels with maximum digital and analog gain. This may be a
     %      specific trait of the Hitachi system and so the alternate
     %      method from 2014 using proportional standard deviation is used instead.
     
     %  References:        
	 %  Takizawa Rejection criteria specificed in Supplementary Material I of:
	 %  Takizawa, R., Kasai, K., Kawakubo, Y., Marumo, K., Kawasaki, S., Yamasue, H., et al. (2008). 
     %      Reduced frontopolar activation during verbal fluency task in schizophrenia: a multi-channel near-infrared spectroscopy study. Schizophr. Res. 99, 250–62. doi:10.10numch/j.schres.2007.10.025.
	 
     % Updated criteria from 
     %  Takizawa, R., Fukuda, M., Kawasaki, S., Kasai, K., Mimura, M., Pu, S., Noda, T., Niwa, S. ichi, Okazaki, Y., Suda, M., Takei, Y., Aoyama, Y., Narita, K., Mikuni, M., Kameyama, M., Uehara, T., Kinou, M., Koike, S., Ishii-Takahashi, A., Ichikawa, N., Fujiwara, M., Ohta, H., Tomioka, H., Yamagata, B., Yamanaka, K., Nakagome, K., Matsuda, T., Yoshida, S., Kono, S., Yabe, H., Miura, S., Nishimura, Y., Tanii, H., Inoue, K., Yokoyama, C., Takayanagi, Y., Takahashi, K., Nakakita, M., 2014. 
