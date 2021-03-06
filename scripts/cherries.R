#CHERRY ANALYSIS OF DATED TREES

require(ape)
require(stringr)
require(ggplot2)

tfolder <- list.files(path="~/PycharmProjects/hiv-evolution-master/8_Dated_Trees/trees", full.names=TRUE)
vfolder <- list.files(path="~/PycharmProjects/hiv-evolution-master/3_RegionSequences/VRegions-final", full.names=TRUE)


len.diff <- list() #data.frame(subtype=character(),stringsAsFactors = F)

# This code reads phylogenetic trees and variable loop sequences in csv format. 
branch.lengths <- data.frame()
genetic.dists <- data.frame()
filtered.indels2 <- data.frame(stringsAsFactors = F)
for (i in 1:length(tfolder)){
  tre <- read.tree(tfolder[i])
  csv <- read.csv(vfolder[i], header=FALSE, stringsAsFactors = F)
  
  #for output 
  name <- strsplit(tfolder[i], "/")[[1]][8]
  subtype <- strsplit(name, "\\.")[[1]][1]
  test <- strsplit(subtype,"_")[[1]]
  if (length(test) == 2){
    subtype <- strsplit(subtype,"_")[[1]][2]
    filename <- paste0(subtype,"+.csv" )
  }else if(subtype == "F1"){
    filename <- paste0(subtype,"+.csv" )
    subtype <- "F1" 
  }else{
    filename <- paste0(subtype,"+.csv" )
  }
  
  
  
  #naming the csv 
  names(csv) <- c('accno', 'VR1', 'VR2','VR3', 'VR4', 'VR5')
  
  #counting tips
  n <- Ntip(tre)
  
  # number of tips per internal node
  # count the number of instances that first column (node) corresponds to a tip number in the second column which is <= n (meaning it is a tip)
  numtips <- tabulate(tre$edge[,1][tre$edge[,2] <= n])
  
  #determines which nodes contain cherries (returns vector with their integer positions)
  is.cherry <- sapply(numtips, function(d) d==2)
  
  
  
  # construct data frame where each row corresponds to a cherry
  m <- sapply(which(is.cherry), function(a) { #will input the numbers of nodes containing 2 tips?
    edge.idx <- tre$edge[,1]==a  # FINDS THE EDGES (row #) corresponding with the parent node ; ap: select rows in edge matrix with parent node index
  
    c(a,   # index of the parent node
      which(edge.idx),
      t(     # transpose so we can concatenate this vector to i
        tre$edge[edge.idx, 2]    # column of tip indices
        )
      )
    })
  df <- data.frame(node.index=m[1,], edge1=m[2,], edge2=m[3,], tip1=m[4,], tip2=m[5,])


  df$tip1.label <- tre$tip.label[df$tip1]
  df$tip2.label <- tre$tip.label[df$tip2]
  df$tip1.len <- tre$edge.length[df$edge1]
  df$tip2.len <- tre$edge.length[df$edge2]
  

  indels <- df[,c(6:9)]
  indels$total.length <- indels$tip1.len + indels$tip2.len
  
  #genetic.dists <- rbind(genetic.dists, data.frame(accno=rep(subtype, nrow(indels)),tip1=indels$tip1.len,tip2=indels$tip2.len, cherry=indels$total.length, ))
  filtered.indels <- indels[indels$total.length != 0,]
  
  filtered.indels2 <- data.frame(stringsAsFactors = F)

  
  indel2 <- data.frame(stringsAsFactors = F)
  nonindel2 <- data.frame(stringsAsFactors = F)
  lens <- c(0,78,120,108,102,33)
  
  
  
  count = 0
  #COUNT THROUGH EACH CHERRY PAIR LISTED IN FILTERED.INDELS
  for (x in 1:nrow(filtered.indels)){
    idxA <- match(filtered.indels$tip1.label[x], csv$accno)
    idxB <- match(filtered.indels$tip2.label[x], csv$accno)
    
    
    indel <- data.frame(stringsAsFactors = F)
    nonindel <- data.frame(stringsAsFactors = F)
    
    #COMPARE ALL FIVE VARIABLE LOOP SEQUENCES IN THAT CHERRY PAIR (ARRANGED BY COLUMNS) 
    for (t in 2:ncol(csv)){

      Avr <- as.character(csv[idxA,t])
      Bvr <- as.character(csv[idxB,t])
      
      Alength <- nchar(Avr)
      Blength <- nchar(Bvr)
      bln <- Alength == Blength
      
      A.B <- paste0(Avr,Bvr)
      
      #NAMES : bln, len, VR length
      names <- c(paste0("VR",as.character(t-1),".indel"), paste0("VR",as.character(t-1),".nt"), paste0("VR",as.character(t-1),".len"))

      #FILTER ----------------------------
      # ? greater than 15% 
      # length is less than 50% of the standard vloop length 
      # if any sequence belonging to V1 - V4 does not start with a Cysteine codon 
      if (Alength < lens[t]/2 || Blength < lens[t]/2 || 
          (str_count(Avr, "\\?")/Alength) > 0.15 || 
          (str_count(Bvr, "\\?")/Blength) > 0.15 ||
          (t !=6 && (as.character(trans(as.DNAbin.DNAString(Avr)))[[1]][1] != "C"|| 
                     as.character(trans(as.DNAbin.DNAString(Bvr)))[[1]][1] != "C")))
      {
        count = count + 1
        print(Avr)
        print(Bvr)
        print("")
        filtered.indels[x,names[1]] <- NA
        filtered.indels[x,names[2]] <- NA
        filtered.indels[x,names[3]] <- (Alength + Blength)/2
      
      # fill the data like normal 
      }else{
        diff <- abs(Alength - Blength)
        filtered.indels[x,names[1]] <- bln
        filtered.indels[x,names[2]] <- diff
        filtered.indels[x,names[3]] <- (Alength + Blength)/2
      }
      
      #for generating 10_Cherries, only indel-containing sequences
      if (!is.na(bln) && !bln){
        indel <- rbind(indel, data.frame(accno1=as.character(csv[idxA,1]), seq1=Avr, accno2=as.character(csv[idxB,1]), seq2=Bvr, Vr=(t-1)))
      #for generating 9_0_nonindel, containing only nonindel sequences
      }else if (!is.na(bln) && isTRUE(bln)){
        nonindel <- rbind(nonindel, data.frame(accno1=as.character(csv[idxA,1]), seq1=Avr, accno2=as.character(csv[idxB,1]), seq2=Bvr, Vr=(t-1)))
      }
      
    } #COLUMNS END
    indel2 <- rbind(indel2, indel)
    nonindel2 <- rbind(nonindel2, nonindel)
    
    
    
  } #ROWS END 
  print(count)
  
  #indel2 = output for cherry sequences in csv format (accno1,seq1,accno2,seq2,vregion) FOLDER: 10_Cherries
  #only cherries with AT LEAST ONE INDEL are directed here
  setwd("~/PycharmProjects/hiv-evolution-master/10_Cherries/")
  write.csv(indel2,filename)
  
  
  setwd("~/PycharmProjects/hiv-evolution-master/9_0_nonindel/")
  write.csv(nonindel2,paste0(filename,"+"))
  
  #filtered indels = true/false outcomes + indel sizes --- used for MLE analysis  FOLDER: 9_indels
  setwd("~/PycharmProjects/hiv-evolution-master/9_2_indels/")
  write.csv(filtered.indels, filename)
  
  branch.lengths <- rbind(branch.lengths, data.frame(subtype=rep(subtype,nrow(filtered.indels)), length=filtered.indels$total.length))
  for (j in 1:5){
    name <- paste0("VR",j,".indel")
    values <- filtered.indels[which(!is.na(filtered.indels[name]) & !filtered.indels[name]),paste0("VR",j,".nt")]
    len.diff[[paste0(filename,".VR",j,".three")]] <- values == 3
    len.diff[[paste0(filename, ".VR",j,".six")]] <-  values == 6
    len.diff[[paste0(filename, ".VR",j,".nine")]] <-  values >= 9
  }
  filtered.indels2 <- rbind(filtered.indels2, data.frame(subtype=rep(subtype,nrow(filtered.indels)),filtered.indels))

}

# cross with the tree_dating file 
#filtered.indels3 <- filtered.indels2[match(genetic.dists$tip1.label, filtered.indels2$tip1.label),]

write.csv(filtered.indels2, "~/vindels/Pipeline_2_Within/filtered-indels.csv")
  
#Used to load the indel.sizes data frame containing 3/6+ indel frequencies
indel.sizes <- data.frame(stringsAsFactors = FALSE)

for (z in 1:length(len.diff)){
  subtype <- strsplit(names(len.diff)[[z]], "\\+.")[[1]][1]
  vregion <- strsplit(strsplit(names(len.diff)[[z]], "\\.")[[1]][3],"VR")[[1]][2]
  size <- strsplit(names(len.diff)[[z]], "\\.")[[1]][4]
  
  if (subtype == "01_AE"){
    subtype <- "AE"
  }else if(subtype == "02_AG"){
    subtype <- "AG"
  }else if (subtype == "F1"){
    subtype <- "F"
  }
  
  indel.sizes[z,"subtype"] <- subtype #vregion
  indel.sizes[z,"count"] <- sum(len.diff[[z]])
  indel.sizes[z,"vregion"] <- paste0("V",vregion)
  if (size == "three"){
    indel.sizes[z,"size"] <- "3"
  }else if (size == "six"){
    indel.sizes[z,"size"] <- "6"
  }else{
    indel.sizes[z,"size"] <- "9+"
  }
  
}


# MOSAIC PLOTS - Figure 3
df3 <- data.frame(variable.loop=rep(indel.sizes$vregion, indel.sizes$count), indel.size=rep(indel.sizes$size,indel.sizes$count),stringsAsFactors = F)
df4 <- data.frame(subtype=rep(indel.sizes$subtype, indel.sizes$count), indel.size=rep(indel.sizes$size,indel.sizes$count))



#used to reorder the data frame so that 9+ is first, 6 is second, etc 
df3$indel.size <- factor(df3$indel.size,levels=c("9+","6","3"))
df3 <- df3[order(df3$indel.size),]

#used to reorder the data frame so that 9+ is first, 6 is second, etc 
df4$indel.size <- factor(df4$indel.size,levels=c("9+","6","3"))
df4$subtype <- factor(df4$subtype, levels=c("AE", "AG", "A1", "B", "C", "D", "F"))
df4 <- df4[order(df4$indel.size),]
df4 <- df4[order(df4$subtype),]

#MOSAIC PLOT -- chi squared data analysis 
d <- as.matrix(table(df3))
c <- chisq.test(d)
c$observed
c$expected

#used for determining the proportions in the mosaic plot
nrow(df3[which(df3$variable.loop=="V2" & df3$indel.size=="3"),])/nrow(df3[which(df3$variable.loop=="V2"),])

require(vcd)

#par(ps = 50, cex.lab = 0.7, cex.axis = 0.5, cex.sub=0.5, las=0, xpd=T, mar=c(5,4, 2,2), mfrow=c(2,2))


m <- mosaic(~variable.loop + indel.size, data=df3,
       shade=T, main=NULL, direction="v",
       spacing=spacing_equal(sp = unit(0.7, "lines")),
       residuals_type="Pearson",
       margins=c(2,2,6,2),
       labeling_args = list(tl_labels = c(F,T), 
                            tl_varnames=c(F,T),
                            gp_labels=gpar(fontsize=24),
                            gp_varnames=gpar(fontsize=28),
                            set_varnames = c(variable.loop="Variable Loop", 
                                             indel.size="Indel Length (nt)"),
                            offset_labels=c(0,0,0,0),rot_labels=c(0,0,0,0), just_labels=c("center","center","center","center")),
       legend=legend_resbased(fontsize = 20, fontfamily = "",
                       x = unit(0.5, "lines"), y = unit(2,"lines"),
                       height = unit(0.8, "npc"),
                       width = unit(1, "lines"), range=c(-10,10)),
       set_labels=list(Variable.Loop=c("V1","V2","V3","V4","V5")))

#par(ps = 27, cex.lab = 0.7, cex.axis = 0.5, cex.sub=0.1, las=0, xpd=T, mar=c(5,4, 2,2), xaxt='n')
mosaic(~subtype + indel.size, data=df4,
       shade=T, main=NULL, direction="v",
       spacing=spacing_equal(sp = unit(0.7, "lines")),
       residuals_type="Pearson",legend=F, 
       margins=c(3,2,6,2),
       labeling_args = list(tl_labels = c(F,T), 
                            tl_varnames=c(F,T), 
                            gp_labels=gpar(fontsize=23),
                            gp_varnames=gpar(fontsize=28),
                            set_varnames = c(subtype="Clade", 
                                             indel.size="Indel Length (nt)"),
                            offset_labels=c(0,0,-0.2,-0.1),rot_labels=c(0,0,35,0), 
                            just_labels=c("center","center","center","center")))


#PHYLOGENETIC PLOT - Figure 1
tre <- read.tree(tfolder[7])



#-------------------------
#load the nt proportions data frame from the temp
# for (g in 1:5){
#   no <- which(temp[,paste0("VR",g,'.indel')])
#   yes <- which(!temp[,paste0("VR",g,'.indel')])
# 
#   nt.prop[i,paste0('VR',g,'.A.no')] <- mean(temp[,paste0('VR',g,'.A')][no])
#   nt.prop[i,paste0('VR',g,'.G.no')] <- mean(temp[,paste0('VR',g,'.G')][no])
#   nt.prop[i,paste0('VR',g,'.T.no')] <- mean(temp[,paste0('VR',g,'.T')][no])
#   nt.prop[i,paste0('VR',g,'.C.no')] <- mean(temp[,paste0('VR',g,'.C')][no])
#   if (length(yes) == 0){
#     nt.prop[i,paste0('VR',g,'.A.yes')] <- 0
#     nt.prop[i,paste0('VR',g,'.G.yes')] <- 0
#     nt.prop[i,paste0('VR',g,'.T.yes')] <- 0
#     nt.prop[i,paste0('VR',g,'.C.yes')] <- 0
#   }else{
#     nt.prop[i,paste0('VR',g,'.A.yes')] <- mean(temp[,paste0('VR',g,'.A')][yes])
#     nt.prop[i,paste0('VR',g,'.G.yes')] <- mean(temp[,paste0('VR',g,'.G')][yes])
#     nt.prop[i,paste0('VR',g,'.T.yes')] <- mean(temp[,paste0('VR',g,'.T')][yes])
#     nt.prop[i,paste0('VR',g,'.C.yes')] <- mean(temp[,paste0('VR',g,'.C')][yes])
#   }
# }
#Used to build the len.diff data frame needed for 3/6+ comparison

